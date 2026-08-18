# AI Resume & Career Suite (MyOwnProject)

An intelligent, full-stack career platform powered by Google Gemini AI with a **Flutter** frontend and **Django REST Framework** backend.

---

## 📁 Project Structure

```text
.
├── frontend/             # Flutter client application (Web, Android, iOS, Desktop)
│   ├── lib/              # Core application source code & screens
│   ├── assets/           # Application icons, fonts, and images
│   └── pubspec.yaml      # Flutter dependencies
│
├── resume_undo/          # Django REST API backend & AI services
│   ├── apps/             # Modular Django apps (resumes, jobs, analysis, users)
│   ├── config/           # Django settings and URL configurations
│   ├── requirements.txt  # Python backend dependencies
│   ├── manage.py         # Django management utility
│   └── .env.example      # Environment variables template
│
├── ai_architecture_document.md # Technical architectural documentation
└── .gitignore            # Git exclusion rules for Python, Flutter & secrets
```

---

## 🚀 Getting Started

### 1. Backend Setup (`resume_undo`)

1. **Navigate to the backend directory**:
   ```bash
   cd resume_undo
   ```

2. **Create and activate a virtual environment**:
   ```bash
   # Windows (PowerShell)
   python -m venv venv
   .\venv\Scripts\Activate.ps1

   # macOS / Linux
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**:
   ```bash
   cp .env.example .env
   ```
   *Edit `.env` to supply your `GEMINI_API_KEY` and any other optional credentials.*

5. **Run database migrations**:
   ```bash
   python manage.py migrate
   ```

6. **Start the development server**:
   ```bash
   python manage.py runserver
   ```
   The backend API will run at `http://127.0.0.1:8000/`.

---

### 2. Frontend Setup (`frontend`)

1. **Navigate to the frontend directory**:
   ```bash
   cd frontend
   ```

2. **Fetch Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Launch the application**:
   ```bash
   # Run on Chrome / Web
   flutter run -d chrome

   # Or run on connected emulator/device
   flutter run
   ```

---

## 🔐 Environment Variables

| Variable | Description | Required |
| :--- | :--- | :--- |
| `GEMINI_API_KEY` | Google Gemini API key for resume parsing & gap analysis | **Yes** |
| `RAZORPAY_KEY_ID` | Razorpay Key ID for payments | No |
| `RAZORPAY_KEY_SECRET` | Razorpay Secret Key | No |
| `RESEND_API_KEY` | Resend API key for transactional emails | No |
| `JSEARCH_API_KEY` | RapidAPI JSearch key for job market queries | No |

---

## 📄 License
Private / Proprietary.
