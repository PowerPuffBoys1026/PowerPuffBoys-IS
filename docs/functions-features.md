# ClassMate - Functions and Features List

## Project Overview

**ClassMate** is a cross-platform client-server application designed to help students organize and track their academic activities in one place. It consists of a Flutter client (Android, iOS, Web, Windows, macOS) and a Node.js + Express REST API with SQLite database.

---

## Core Features

### 1. User Authentication & Account Management
- [x] **User Registration** - Create a new account with email, password, full name, student number, and course
- [x] **User Login** - Secure login using email and password with JWT token-based authentication
- [x] **Get Current User** - Retrieve authenticated user profile information
- [x] **Session Management** - Persistent sessions using secure token storage
- [x] **Password Security** - Passwords are hashed using bcryptjs

### 2. Subjects Management
- [x] **View All Subjects** - Display all subjects created by the user
- [x] **Add New Subject** - Create subjects with code, title, instructor, units, and color
- [x] **View Subject Details** - View individual subject information
- [x] **Update Subject** - Edit subject details
- [x] **Delete Subject** - Remove subjects from the system
- [x] **Subject Color Coding** - Assign custom colors to subjects for visual organization

### 3. Schedule/Timetable Management
- [x] **View Weekly Schedule** - View class schedule for all days of the week
- [x] **Filter by Day** - Filter schedule by specific day (Sunday to Saturday)
- [x] **Add Class Slot** - Create schedule entries with subject, day, time, room, and modality
- [x] **Edit Class Slot** - Update existing schedule entries
- [x] **Delete Class Slot** - Remove class slots from timetable
- [x] **Time Validation** - Ensures valid 24-hour time format (HH:MM)
- [x] **Subject Integration** - Schedule slots linked to user-owned subjects

### 4. Attendance Tracking
- [x] **Mark Attendance** - Record attendance for a class session (Present, Absent, Late, Cancelled)
- [x] **View Attendance Records** - List all attendance records with filtering options
- [x] **Filter Attendance** - Filter by subject, date range (from/to)
- [x] **Update Attendance Record** - Edit existing attendance entries
- [x] **Delete Attendance Record** - Remove attendance records
- [x] **Attendance Summary** - Per-subject attendance statistics with rates
- [x] **Absence Warning System** - Automatic warnings when absence rate reaches or exceeds threshold (default 20%)
- [x] **Duplicate Prevention** - Prevents marking attendance twice for the same subject/session/date
- [x] **Smart Calculation** - Attendance rate = (Present / (Present + Absent + Late)) * 100, Cancelled sessions ignored

### 5. School Works/Tasks Management
- [x] **View All School Works** - Display all assignments, quizzes, exams, and projects
- [x] **Add School Work** - Create tasks with title, subject, type, due date, priority, status, and notes
- [x] **View School Work Details** - View individual task information
- [x] **Update School Work** - Edit all task details
- [x] **Quick Status Update** - Change status via PATCH endpoint (Todo, Doing, Done)
- [x] **Delete School Work** - Remove tasks from the list
- [x] **Filter School Works** - Filter by status, subject, or due date
- [x] **Smart Sorting** - Unfinished tasks first, then sorted by due date
- [x] **Subject Association** - Link tasks to subjects or leave unassigned
- [x] **Overdue Detection** - Identify overdue tasks
- [x] **Task Types** - Support for Assignment, Quiz, Exam, and Project
- [x] **Priority Levels** - Low, Medium, High priority classification

### 6. Dashboard
- [x] **Today's Overview** - View all classes scheduled for the current day
- [x] **Due Soon Section** - Display unfinished tasks due within the next 7 days (including overdue)
- [x] **Attendance Warnings** - Quick view of subjects exceeding absence threshold
- [x] **Day Information** - Shows current date and day of the week
- [x] **Quick Access** - Centralized view of important daily information

---

## Technical Functions

### Backend (Node.js + Express)
- [x] **RESTful API Architecture** - Clean REST endpoints following HTTP conventions
- [x] **MVC Pattern** - Organized with Models, Views (JSON serializers), and Controllers
- [x] **JWT Authentication Middleware** - Protected routes with token verification
- [x] **Input Validation** - Request validation using Zod schemas
- [x] **Error Handling** - Consistent JSON error responses with proper HTTP status codes
- [x] **Owner-Scoped Data** - All data filtered by authenticated user (prevents cross-user access)
- [x] **SQLite Database** - Lightweight, file-based database with better-sqlite3
- [x] **Automatic Schema Creation** - Database tables created on first run
- [x] **Foreign Key Constraints** - Data integrity with cascading deletes
- [x] **Database Indexes** - Optimized queries for better performance
- [x] **Environment Configuration** - Configurable via .env file
- [x] **CORS Support** - Cross-origin requests enabled for client communication
- [x] **Seed Data** - Demo account and sample data for testing

### Frontend (Flutter)
- [x] **Cross-Platform Support** - Runs on Android, iOS, Web, Windows, and macOS
- [x] **State Management** - Using Provider package for reactive state
- [x] **API Integration** - HTTP client for REST API communication
- [x] **Secure Token Storage** - Local storage for authentication tokens
- [x] **Dark Theme (Midnight Glass)** - Modern glassmorphism UI with animated background
- [x] **Responsive Design** - Adapts to different screen sizes
- [x] **Form Validation** - Client-side input validation
- [x] **Loading States** - Visual feedback during async operations
- [x] **Error Display** - User-friendly error messages
- [x] **Material Design 3** - Modern UI components

---

## API Endpoints

| Category | Method | Endpoint | Function |
|---|---|---|---|
| **Health** | GET | `/api/health` | API health check |
| **Auth** | POST | `/api/auth/register` | Register new user |
| **Auth** | POST | `/api/auth/login` | User login |
| **Auth** | GET | `/api/auth/me` | Get current user |
| **Subjects** | GET | `/api/subjects` | List all subjects |
| **Subjects** | POST | `/api/subjects` | Create subject |
| **Subjects** | GET | `/api/subjects/:id` | Get subject details |
| **Subjects** | PUT | `/api/subjects/:id` | Update subject |
| **Subjects** | DELETE | `/api/subjects/:id` | Delete subject |
| **Schedule** | GET | `/api/schedule?day=` | List schedule slots (optional day filter) |
| **Schedule** | POST | `/api/schedule` | Create schedule slot |
| **Schedule** | PUT | `/api/schedule/:id` | Update schedule slot |
| **Schedule** | DELETE | `/api/schedule/:id` | Delete schedule slot |
| **Attendance** | GET | `/api/attendance` | List attendance records (filters: subjectId, from, to) |
| **Attendance** | POST | `/api/attendance` | Mark attendance |
| **Attendance** | PUT | `/api/attendance/:id` | Update attendance record |
| **Attendance** {
| DELETE | `/api/attendance/:id` | Delete attendance record | | **Attendance** | GET | `/api/attendance/summary` | Get attendance summary with warnings | | **Works** | GET | `/api/works` | List school works (filters: status, subjectId, dueBefore) | | **Works** | POST | `/api/works` | Create school work | | **Works** | GET | `/api/works/:id` | Get school work details | | **Works** | PUT | `/api/works/:id` | Update school work | | **Works** | PATCH | `/api/works/:id/status` | Update work status | | **Works** | DELETE | `/api/works/:id` | Delete school work | | **Dashboard** | GET | `/api/dashboard/today` | Get today's overview | 

---

## Features Not Yet Implemented (Stretch Goals)

- [ ] **Notifications/Reminders** - Local push notifications for classes and deadlines
- [ ] **Dark/Light Theme Toggle** - User selectable theme mode
- [ ] **Attendance Reports** - Export attendance data
- [ ] **Priority Sorting Polish** - Enhanced sorting options
- [ ] **QR Check-in** - Quick attendance marking via QR code
- [ ] **Offline Sync** - Offline functionality with data synchronization
- [ ] **Cloud Push Notifications** - Remote notifications
- [ ] **Chat/Collaborative Features** - Group study features
- [ ] **Image Uploads** - Attach files or images to school works

---

## Demo Credentials

**Email:** `demo@classmate.app`  
**Password:** `demo12345`

---

**Last Updated:** October 24, 2026
**Version:** 1.0.0
**Group:** 7 - PowerPuffBoys
**Architecture:** Client-Server (Full-Stack)
**Type:** Cross-platform API-driven application
