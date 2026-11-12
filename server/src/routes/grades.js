const express = require('express');
const { z } = require('zod');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const { validate } = require('../utils/validate');
const { asyncHandler } = require('../utils/asyncHandler');
const { HttpError } = require('../utils/errors');
const recycleBin = require('../services/recycle_bin');
const { parseId } = require('../utils/parse');

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
    weightPct: Number(row.weight_pct),
    scorePct: row.score_pct == null ? null : Number(row.score_pct),
    targetPct: row.target_pct == null ? 85 : Number(row.target_pct),
    createdAt: row.created_at,
  };
}

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

router.get('/', asyncHandler(async (req, res) => {
  const rows = await db.query('SELECT * FROM fn_grades_list($1)', [req.userId]);
  res.json({ data: rows.rows.map(toGrade) });
}));

router.post('/', asyncHandler(async (req, res) => {
  const data = validate(gradeSchema, req.body);
  const subject = await db.query('SELECT fn_subject_owned($1,$2) AS exists', [data.subjectId, req.userId]);
  if (!subject.rows[0]?.exists) throw new HttpError(404, 'Subject not found');
  const row = await db.query('SELECT * FROM fn_grade_create($1,$2,$3,$4,$5,$6)', [
    req.userId, data.subjectId, data.componentName, data.weightPct, data.scorePct ?? null, data.targetPct ?? 85,
  ]);
  res.status(201).json({ data: toGrade(row.rows[0]) });
}));

router.put('/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const current = await db.query('SELECT * FROM fn_grade_owned($1,$2)', [id, req.userId]);
  if (!current.rows[0]) throw new HttpError(404, 'Grade item not found');
  const cur = current.rows[0];
  const data = validate(gradeUpdateSchema, req.body);
  const setScore = Object.prototype.hasOwnProperty.call(data, 'scorePct');
  const updated = await db.query('SELECT * FROM fn_grade_update($1,$2,$3,$4,$5,$6,$7)', [
    id, req.userId,
    data.componentName ?? cur.component_name,
    data.weightPct ?? cur.weight_pct,
    setScore ? (data.scorePct ?? null) : null,
    setScore,
    data.targetPct ?? cur.target_pct,
  ]);
  res.json({ data: toGrade(updated.rows[0]) });
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const current = await db.query('SELECT * FROM fn_grade_owned($1,$2)', [id, req.userId]);
  if (!current.rows[0]) throw new HttpError(404, 'Grade item not found');
  const recycleBinId = await recycleBin.trashRecord(req.userId, 'grade', id);
  res.json({ data: { success: true, recycleBinId } });
}));

router.get('/summary', asyncHandler(async (req, res) => {
  const [subjectsRes, gradesRes] = await Promise.all([
    db.query('SELECT * FROM fn_grade_summary_subjects($1)', [req.userId]),
    db.query('SELECT * FROM fn_grade_summary_grades($1)', [req.userId]),
  ]);
  const allGrades = gradesRes.rows;
  let totalWeightedGpa = 0;
  let totalUnitsCounted = 0;

  const subjectSummaries = subjectsRes.rows.map((sub) => {
    const components = allGrades.filter((g) => g.subject_id === sub.id);
    let totalGradedWeight = 0;
    let earnedWeight = 0;
    let totalTarget = 85;
    for (const c of components) {
      if (c.score_pct !== null && c.score_pct !== undefined) {
        earnedWeight += (Number(c.score_pct) * Number(c.weight_pct)) / 100;
        totalGradedWeight += Number(c.weight_pct);
      }
      if (c.target_pct != null) totalTarget = Number(c.target_pct);
    }
    const currentPercentage = totalGradedWeight > 0 ? Math.round((earnedWeight / totalGradedWeight) * 1000) / 10 : null;
    const remainingWeight = Math.max(0, 100 - totalGradedWeight);
    let neededOnRemaining = null;
    if (remainingWeight > 0) {
      const neededScore = ((totalTarget - earnedWeight) / remainingWeight) * 100;
      neededOnRemaining = Math.round(neededScore * 10) / 10;
    }
    const { gpa, letter } = percentageToGpa(currentPercentage);
    const units = sub.units || 3;
    if (gpa !== null) { totalWeightedGpa += gpa * units; totalUnitsCounted += units; }
    return {
      subjectId: sub.id, code: sub.code, title: sub.title, units, color: sub.color,
      componentsCount: components.length, currentPercentage, letterGrade: letter, gpa,
      targetPercentage: totalTarget, remainingWeight, neededOnRemaining,
      components: components.map((c) => ({ id: c.id, componentName: c.component_name, weightPct: Number(c.weight_pct), scorePct: c.score_pct == null ? null : Number(c.score_pct), targetPct: c.target_pct == null ? 85 : Number(c.target_pct) })),
    };
  });

  const cumulativeGpa = totalUnitsCounted > 0 ? Math.round((totalWeightedGpa / totalUnitsCounted) * 100) / 100 : null;
  let academicStanding = 'On Track';
  if (cumulativeGpa !== null) {
    if (cumulativeGpa >= 3.8) academicStanding = "President's List Pace";
    else if (cumulativeGpa >= 3.5) academicStanding = "Dean's List Pace";
    else if (cumulativeGpa >= 3.0) academicStanding = 'Good Standing';
    else if (cumulativeGpa < 2.0) academicStanding = 'Academic Warning';
  }
  res.json({ data: { cumulativeGpa, academicStanding, totalUnitsCounted, subjects: subjectSummaries } });
}));

module.exports = router;
