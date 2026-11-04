# 🌿 ADHD Budget Planner – Production Authentication, Bills Management & Expense Tracking

A modern, low-stimulation, ADHD-friendly personal financial application built with HTML5, modern Tailwind CSS, Lucide Icons, and complete **production-ready Supabase Authentication**.

Designed specifically to reduce financial avoidance, decision fatigue, and overwhelming clutter for neurodivergent minds.

---

## 🌟 Major Features & Recent Updates

### 1. Production-Ready Supabase Authentication & Session Restoration
- **Full Registration & Unique Usernames**:
  - Full Name, Unique Username, Email Address, and Password with visibility toggles.
  - Checks username uniqueness before signup via database RPC / `profiles` table.
- **Flexible Login**:
  - Sign in with **Email + Password** OR **Unique Username + Password**.
  - Automatically resolves usernames to their corresponding registered email address.
  - "Remember me" option to maintain persistent sessions.
- **Automatic Session Restoration**:
  - Automatically restores authenticated sessions on browser refresh using `@supabase/supabase-js` secure storage.
  - Returning users are directed straight to their personalized financial dashboard.
  - **Never forces an existing user to repeat initial budget onboarding**.
- **Account Recovery & Password Reset**:
  - "Forgot Password" modal generates a secure password reset email via `supabase.auth.resetPasswordForEmail()`.
  - When returning from a reset link, automatically triggers `PASSWORD_RECOVERY` to open the "Set New Password" modal and updates credentials via `supabase.auth.updateUser()`.
- **Isolated Multi-Tenant Security**:
  - Every financial record (`monthly_budgets`, `budget_categories`, `expenses`, `bills`, `calendar_tasks`, `user_settings`) is strictly tied to `auth.uid() = user_id`.
  - PostgreSQL Row Level Security (RLS) guarantees users never see or modify another user's financial data.

### 2. Bills Management – Edit, Delete & Automatic Payment Calculations
- **Action Icons on Every Bill**:
  - **Edit Bill**: Edit bill name, amount, budget category, due date, recurring frequency (`monthly`, `weekly`, `yearly`, `none`), and optional notes.
  - **Delete Bill**: Protected deletion with confirmation dialog. When a paid bill is deleted, its past payment history and recorded expenses are **safely preserved** without distorting your financial ledger.
  - **Mark as Paid / Mark as Unpaid**: Interactive one-tap toggle with full financial recalculation.
- **Automatic Payment & Expense Synchronization**:
  - Unpaid bills are never counted toward actual monthly spending.
  - When marked as **Paid**:
    - Automatically creates a linked payment record in the Expenses system (`${bill.name} Payment`).
    - Increases **Total Spent** immediately by the bill amount.
    - Decreases **Remaining Budget** immediately.
    - Updates relevant **Category Spending** and progress bar in real time.
    - Displays payment date badge (`Paid on Jan 24` / `Settled on Nov 4`).
  - **Strict Duplicate Prevention**:
    - If a bill is already paid, toggling or clicking cannot create duplicate expense entries (`idx_unique_bill_payment`).
    - If marked back to **Unpaid**, the linked expense is safely removed, immediately restoring the spent amount and remaining budget.

### 3. Expense Tracking & Category Breakdown
- **Prominent Add Expense Buttons**: Available directly on the Home Dashboard, Monthly Budget page, and individual category cards.
- **Category-Specific Breakdown Modal**: Clicking any category displays:
  - Monthly Allocation
  - Spent Amount
  - Remaining Balance
  - Spending Progress Percentage
  - Complete list of transactions under that category with edit and delete actions.
- **Filterable Expense History**: Filter expenses by Month, Category, or search description.

### 4. Editable Monthly Budget Categories
- **Fully Customizable**: Add, rename, edit planned amounts, and select from Lucide icons.
- **Dynamic Recalculations**:
  - Total Monthly Budget = Sum of category allocations + unallocated buffer.
  - Total Spent = Sum of recorded expenses in active month.
  - Remaining Budget = Total Monthly Budget - Total Spent.
- **Safe Reassignment**: Deleting a category with existing expenses prompts reassignment or archiving without data loss.

### 5. Today's Tasks Section on Home Dashboard & Calendar Synchronization
- **Dedicated Home Dashboard Widget**:
  - Automatically fetches and displays all tasks scheduled for the current date from `currentUserData.calendarTasks`.
  - **ADHD-Friendly Hierarchy**:
    - Pending tasks automatically sort before completed tasks.
    - Subtle completed visual style (subtle strikethrough, muted tone, visible checkbox).
    - Real-time completion counter (e.g. `2 of 4 completed`) with an interactive visual progress bar.
    - Encouraging, clutter-free empty state when no tasks are scheduled: *"No tasks planned for today. You're all set!"* with a direct `+ Add a task for today` action.
  - **One-Tap Task Completion**:
    - Toggle checkbox directly on the Home Dashboard.
    - Gentle confetti animation and supportive toast notification (`🌱 Nice work! One small step completed.`).
    - State persists immediately across reloads, page changes, and logins.
  - **Direct "Add Task" from Home**:
    - Quick "+ Add Task" button in the Today's Tasks widget header.
    - Modal pre-filled with today's local date (`YYYY-MM-DD`).
    - Tasks scheduled for today appear immediately on both Home Dashboard and Calendar views.
    - Tasks scheduled for future or other dates appear on their respective calendar dates and never clutter the Home Dashboard.
  - **Timezone Accuracy**:
    - Uses local device timezone dates (`getTodayIso()`), preventing UTC date boundary shifts.

---

## ⚙️ Configuration & Environment Setup

This project is prepared for GitHub deployment with environment variables and credentials protection:

1. **`config.js`**: Contains client-side configuration. You can specify your Supabase credentials here for development:
   ```javascript
   window.__ENV__ = window.__ENV__ || {
     SUPABASE_URL: 'https://your-project.supabase.co',
     SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsIn...'
   };
   ```
2. **In-App "Connect Supabase" Dialog**: You can also click the **Supabase** status badge in the header to enter or test credentials interactively. Credentials are saved safely in your browser storage.
3. **`.env.example`**: Standard environment template. Copy to `.env` for containerized or build-step environments:
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
4. **`.gitignore`**: Prevents accidental commits of `.env` files, local secrets, and operating system artifacts to git.

---

## 🗄️ Database & Security Layer (`supabase_schema.sql`)

Execute `supabase_schema.sql` in your Supabase SQL Editor:
- **`profiles` Table**:
  - `id uuid references auth.users primary key`, `full_name`, `username text unique`, `email`, `currency`, `onboarded boolean`.
  - RPC function `get_email_for_username(p_username text)` to support username login.
  - RPC function `is_username_available(p_username text)` to validate unique usernames during signup.
- **`monthly_budgets` Table**: `user_id`, `month_year`, `total_budget`, `currency`.
- **`budget_categories` Table**: `user_id`, `name`, `icon`, `planned_amount`, `spent_amount`, `archived_at`.
- **`expenses` Table**: `user_id`, `category_name`, `expense_name`, `amount`, `expense_date`, `bill_id`.
  - `create unique index idx_unique_bill_payment on public.expenses(bill_id) where bill_id is not null;`
- **`bills` Table**: `user_id`, `bill_name`, `amount`, `category_name`, `due_date`, `status`, `is_paid`, `paid_at`, `recurring_frequency`.
- **`calendar_tasks` Table**: `user_id`, `title`, `description`, `category_name`, `task_date`, `start_time`, `end_time`, `completed`.
- **`user_settings` Table**: `user_id`, `theme`, `enable_confetti`, `autofocus_inputs`.
- **Row Level Security (RLS)**: Enforced across all tables so users can only access their own records (`auth.uid() = user_id`).

---

## 🚀 How to Run & Test

Open `index.html` in your browser:
```powershell
Start-Process "C:\Users\It's Sunny\.gemini\antigravity\scratch\adhd-budget-planner\index.html"
```
