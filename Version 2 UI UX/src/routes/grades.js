const express = require('express');
const { z } = require('zod');

const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../utils/validate');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');

const router = express.Router();
router.use(requireAuth);

const gradeSchema = z.object({
  subjectId: z.number().int(),
  componentName: z.string().min(1, 'Component name is required'),
  weightPct: z.number().min(0).max(100),
  scorePct: z.number().min(0).max(100).nullish(),
  targetPct: z.number().min(0).max(100).default(85),
});

const gradeUpdateSchema = gradeSchema.partial();

function toGrade(row) {
  return {
    id: row.id,
    subjectId: row.subject_id,
    subjectCode: row.subject_code,
    subjectTitle: row.subject_title,
    componentName: row.component_name,
    weightPct: row.weight_pct,
    scorePct: row.score_pct,
    targetPct: row.target_pct,
    createdAt: row.created_at,
  };
}

// Convert percentage score to standard 4.0 GPA scale and Letter grade
function percentageToGpa(pct) {
  if (pct === null || pct === undefined) return { gpa: null, letter: 'N/A' };
  if (pct >= 93) return { gpa: 4.0, letter: 'A' };
  if (pct >= 90) return { gpa: 3.7, letter: 'A-' };
  if (pct >= 87) return { gpa: 3.3, letter: 'B+' };
  if (pct >= 83) return { gpa: 3.0, letter: 'B' };
  if (pct >= 80) return { gpa: 2.7, letter: 'B-' };
  if (pct >= 77) return { gpa: 2.3, letter: 'C+' };
  if (pct >= 73) return { gpa: 2.0, letter: 'C' };
  if (pct >= 70) return { gpa: 1.7, letter: 'C-' };
  if (pct >= 60) return { gpa: 1.0, letter: 'D' };
  return { gpa: 0.0, letter: 'F' };
}

// GET /api/grades
router.get('/', (req, res) => {
  const rows = db
    .prepare(
      `SELECT g.id, g.subject_id, g.component_name, g.weight_pct, g.score_pct, g.target_pct, g.created_at,
              s.code AS subject_code, s.title AS subject_title
         FROM subject_grades g
         JOIN subjects s ON s.id = g.subject_id
        WHERE g.user_id = ?
        ORDER BY s.code, g.component_name`,
    )
    .all(req.userId);

  res.json({ data: rows.map(toGrade) });
});

// POST /api/grades
router.post('/', (req, res) => {
  const data = validate(gradeSchema, req.body);

  const subject = db
    .prepare('SELECT id FROM subjects WHERE id = ? AND user_id = ?')
    .get(data.subjectId, req.userId);
  if (!subject) throw new HttpError(404, 'Subject not found');

  const info = db
    .prepare(
      `INSERT INTO subject_grades (user_id, subject_id, component_name, weight_pct, score_pct, target_pct)
       VALUES (?, ?, ?, ?, ?, ?)`,
    )
    .run(
      req.userId,
      data.subjectId,
      data.componentName,
      data.weightPct,
      data.scorePct ?? null,
      data.targetPct ?? 85,
    );

  const row = db
    .prepare(
      `SELECT g.id, g.subject_id, g.component_name, g.weight_pct, g.score_pct, g.target_pct, g.created_at,
              s.code AS subject_code, s.title AS subject_title
         FROM subject_grades g
         JOIN subjects s ON s.id = g.subject_id
        WHERE g.id = ?`,
    )
    .get(info.lastInsertRowid);

  res.status(201).json({ data: toGrade(row) });
});

// PUT /api/grades/:id
router.put('/:id', (req, res) => {
  const current = db
    .prepare('SELECT id, subject_id, component_name, weight_pct, score_pct, target_pct FROM subject_grades WHERE id = ? AND user_id = ?')
    .get(req.params.id, req.userId);
  if (!current) throw new HttpError(404, 'Grade item not found');

  const data = validate(gradeUpdateSchema, req.body);

  db.prepare(
    `UPDATE subject_grades
        SET component_name = ?, weight_pct = ?, score_pct = ?, target_pct = ?
      WHERE id = ?`,
  ).run(
    data.componentName ?? current.component_name,
    data.weightPct ?? current.weight_pct,
    data.scorePct !== undefined ? data.scorePct : current.score_pct,
    data.targetPct ?? current.target_pct,
    req.params.id,
  );

  const updated = db
    .prepare(
      `SELECT g.id, g.subject_id, g.component_name, g.weight_pct, g.score_pct, g.target_pct, g.created_at,
              s.code AS subject_code, s.title AS subject_title
         FROM subject_grades g
         JOIN subjects s ON s.id = g.subject_id
        WHERE g.id = ?`,
    )
    .get(req.params.id);

  res.json({ data: toGrade(updated) });
});

// DELETE /api/grades/:id
router.delete('/:id', (req, res) => {
  const current = db
    .prepare('SELECT id FROM subject_grades WHERE id = ? AND user_id = ?')
    .get(req.params.id, req.userId);
  if (!current) throw new HttpError(404, 'Grade item not found');

  const recycleBinId = recycleBin.trashRecord(req.userId, 'grade', Number(req.params.id));
  res.json({ data: { success: true, recycleBinId } });
});

// GET /api/grades/summary
router.get('/summary', (req, res) => {
  const subjects = db
    .prepare('SELECT id, code, title, units, color FROM subjects WHERE user_id = ? ORDER BY code')
    .all(req.userId);

  const allGrades = db
    .prepare('SELECT * FROM subject_grades WHERE user_id = ?')
    .all(req.userId);

  let totalWeightedGpa = 0;
  let totalUnitsCounted = 0;

  const subjectSummaries = subjects.map((sub) => {
    const components = allGrades.filter((g) => g.subject_id === sub.id);
    let totalGradedWeight = 0;
    let earnedWeight = 0;
    let totalTarget = 85;

    for (const c of components) {
      if (c.score_pct !== null && c.score_pct !== undefined) {
        earnedWeight += (c.score_pct * c.weight_pct) / 100;
        totalGradedWeight += c.weight_pct;
      }
      if (c.target_pct) totalTarget = c.target_pct;
    }

    const currentPercentage =
      totalGradedWeight > 0 ? Math.round((earnedWeight / totalGradedWeight) * 1000) / 10 : null;

    const remainingWeight = Math.max(0, 100 - totalGradedWeight);
    let neededOnRemaining = null;
    if (remainingWeight > 0) {
      const neededScore = ((totalTarget - earnedWeight) / remainingWeight) * 100;
      neededOnRemaining = Math.round(neededScore * 10) / 10;
    }

    const { gpa, letter } = percentageToGpa(currentPercentage);

    const units = sub.units || 3;
    if (gpa !== null) {
      totalWeightedGpa += gpa * units;
      totalUnitsCounted += units;
    }

    return {
      subjectId: sub.id,
      code: sub.code,
      title: sub.title,
      units,
      color: sub.color,
      componentsCount: components.length,
      currentPercentage,
      letterGrade: letter,
      gpa,
      targetPercentage: totalTarget,
      remainingWeight,
      neededOnRemaining,
      components: components.map((c) => ({
        id: c.id,
        componentName: c.component_name,
        weightPct: c.weight_pct,
        scorePct: c.score_pct,
        targetPct: c.target_pct,
      })),
    };
  });

  const cumulativeGpa =
    totalUnitsCounted > 0 ? Math.round((totalWeightedGpa / totalUnitsCounted) * 100) / 100 : null;

  let academicStanding = 'On Track';
  if (cumulativeGpa !== null) {
    if (cumulativeGpa >= 3.8) academicStanding = "President's List Pace 🏆";
    else if (cumulativeGpa >= 3.5) academicStanding = "Dean's List Pace ⭐";
    else if (cumulativeGpa >= 3.0) academicStanding = 'Good Standing ✨';
    else if (cumulativeGpa < 2.0) academicStanding = 'Academic Warning ⚠️';
  }

  res.json({
    data: {
      cumulativeGpa,
      academicStanding,
      totalUnitsCounted,
      subjects: subjectSummaries,
    },
  });
});

module.exports = router;
