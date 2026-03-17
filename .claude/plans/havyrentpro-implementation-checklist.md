# HavyRentPro -- Implementation Checklist

> Heavy equipment rental platform -- portfolio project.
> Each item below is an atomic, actionable task. Check them off as you go.
> Items marked with (BE) are backend, (FE) are frontend, (INFRA) are infrastructure.

---

## 1. Django App Structure

Seven apps under `backend/apps/`, organized by domain (not by technical layer).

### 1.1 `core` -- Shared Foundation

Contains abstract base models, DRF permission classes, pagination, custom exception handler, shared enums. No database tables of its own.

- [ ] **1.1.1** (BE) Create the `core` app package with `__init__.py`
- [ ] **1.1.2** (BE) Implement `TimeStampedModel` abstract base model (`created_at`, `updated_at` auto fields)
- [ ] **1.1.3** (BE) Implement `UUIDModel` abstract base model (UUID v4 primary key) -- combine with TimeStamped into a single `BaseModel`
- [ ] **1.1.4** (BE) Implement `IsOwnerPermission` DRF permission class (checks `user.role == OWNER`)
- [ ] **1.1.5** (BE) Implement `IsTenantPermission` DRF permission class (checks `user.role == TENANT`)
- [ ] **1.1.6** (BE) Implement `IsObjectOwnerPermission` DRF permission class (object-level: checks `obj.owner == request.user`)
- [ ] **1.1.7** (BE) Implement `IsBookingParticipantPermission` (object-level: user is either tenant or equipment owner on the booking)
- [ ] **1.1.8** (BE) Implement `StandardResultsSetPagination` (page size 20, max 100)
- [ ] **1.1.9** (BE) Implement custom DRF exception handler (consistent JSON error format: `{"error": {"code": ..., "message": ..., "details": ...}}`)
- [ ] **1.1.10** (BE) Define shared enums module: `UserRole`, `BookingStatus`, `PaymentStatus`, `EquipmentCategory`

### 1.2 `accounts` -- Auth and RBAC

Owns the User model, JWT authentication, email verification, user profiles.

- [ ] **1.2.1** (BE) Create the `accounts` app with standard Django structure
- [ ] **1.2.2** (BE) Implement custom `User` model extending `AbstractUser` with fields: uuid pk, email (unique, used as username), first_name, last_name, phone, role (TENANT/OWNER), is_email_verified, timestamps
- [ ] **1.2.3** (BE) Implement custom `UserManager` with `create_user` / `create_superuser` using email as identifier
- [ ] **1.2.4** (BE) Implement `EmailVerificationToken` model (uuid pk, user FK, token string unique, expires_at, is_used)
- [ ] **1.2.5** (BE) Create and run initial migrations
- [ ] **1.2.6** (BE) Configure SimpleJWT in settings (access token 30min, refresh token 7 days, rotate refresh tokens)
- [ ] **1.2.7** (BE) Implement registration serializer (email, password, password_confirm, first_name, last_name, role)
- [ ] **1.2.8** (BE) Implement registration view (POST `/auth/register/`) -- creates user, dispatches email verification task
- [ ] **1.2.9** (BE) Implement login view (POST `/auth/login/`) -- SimpleJWT TokenObtainPairView
- [ ] **1.2.10** (BE) Implement token refresh view (POST `/auth/token/refresh/`)
- [ ] **1.2.11** (BE) Implement email verification view (POST `/auth/verify-email/`) -- accepts token, marks user verified
- [ ] **1.2.12** (BE) Implement user profile view (GET/PATCH `/auth/me/`) -- returns/updates profile, rejects role changes
- [ ] **1.2.13** (BE) Wire post_save signal on User creation to dispatch `send_verification_email` Celery task
- [ ] **1.2.14** (BE) Register User and EmailVerificationToken in Django admin

### 1.3 `equipment` -- Equipment Catalog

Owns equipment listings, photos, search/filter, occupancy calendar. Also serves Owner dashboard equipment and stats endpoints.

- [ ] **1.3.1** (BE) Create the `equipment` app
- [ ] **1.3.2** (BE) Implement `Equipment` model (uuid pk, owner FK to User, title, description text, category enum, daily_rate decimal, location string, is_available bool, timestamps)
- [ ] **1.3.3** (BE) Implement `EquipmentPhoto` model (uuid pk, equipment FK, image FileField, sort_order int, is_primary bool)
- [ ] **1.3.4** (BE) Create and run migrations
- [ ] **1.3.5** (BE) Implement public equipment list viewset with search and filters using `django-filter`: category, location, min_price, max_price, search (full-text on title+description), available_from/available_to (date range exclusion of booked equipment)
- [ ] **1.3.6** (BE) Implement public equipment detail view (returns equipment with nested photos serializer)
- [ ] **1.3.7** (BE) Implement occupancy calendar endpoint (GET `/equipment/{id}/calendar/`) -- returns list of booked date ranges from confirmed/paid bookings
- [ ] **1.3.8** (BE) Implement owner-only equipment CRUD viewset (create sets owner=request.user, update/delete restricted to equipment owner)
- [ ] **1.3.9** (BE) Implement photo upload endpoint (POST `/equipment/{id}/photos/`) -- accepts multiple files
- [ ] **1.3.10** (BE) Implement photo delete endpoint (DELETE `/equipment/{id}/photos/{photo_id}/`)
- [ ] **1.3.11** (BE) Implement photo reorder endpoint (PATCH `/equipment/{id}/photos/reorder/`) -- accepts ordered list of photo IDs
- [ ] **1.3.12** (BE) Implement dashboard stats endpoint (GET `/dashboard/stats/`) -- total income, active listings, idle equipment count, booking counts by status
- [ ] **1.3.13** (BE) Implement dashboard equipment list endpoint (GET `/dashboard/equipment/`) -- owner's equipment with booking summary
- [ ] **1.3.14** (BE) Register Equipment and EquipmentPhoto in Django admin

### 1.4 `bookings` -- Booking Lifecycle

Owns booking creation, draft reservation via Redis, status state machine, and the dashboard booking management endpoint.

- [ ] **1.4.1** (BE) Create the `bookings` app
- [ ] **1.4.2** (BE) Implement `Booking` model (uuid pk, equipment FK, tenant FK to User, start_date, end_date, total_price decimal, status enum DRAFT/PENDING/CONFIRMED/PAID/COMPLETED/REJECTED/CANCELLED, rejection_reason text nullable, timestamps)
- [ ] **1.4.3** (BE) Create and run migrations
- [ ] **1.4.4** (BE) Implement `DraftBookingService` -- Redis SET with key `draft:{equipment_id}:{user_id}`, 15-min TTL; methods: `create_draft`, `get_draft`, `delete_draft`, `is_locked`
- [ ] **1.4.5** (BE) Implement draft booking endpoint (POST `/bookings/draft/`) -- checks availability, creates Redis lock, returns draft info
- [ ] **1.4.6** (BE) Implement booking creation endpoint (POST `/bookings/`) -- validates draft exists and not expired, creates DB record as PENDING, deletes Redis draft
- [ ] **1.4.7** (BE) Implement booking list endpoint (GET `/bookings/`) -- tenant sees own bookings, owner sees bookings for their equipment; supports status filter
- [ ] **1.4.8** (BE) Implement booking detail endpoint (GET `/bookings/{id}/`)
- [ ] **1.4.9** (BE) Implement booking action endpoints as separate views:
  - POST `/bookings/{id}/confirm/` (Owner only, PENDING -> CONFIRMED)
  - POST `/bookings/{id}/reject/` (Owner only, PENDING -> REJECTED, requires rejection_reason)
  - POST `/bookings/{id}/cancel/` (Tenant only, allowed from PENDING or CONFIRMED)
  - POST `/bookings/{id}/complete/` (Owner only, PAID -> COMPLETED)
- [ ] **1.4.10** (BE) Implement status transition validation (reject invalid transitions with 400)
- [ ] **1.4.11** (BE) Implement date overlap validation on booking creation (no two non-cancelled bookings for same equipment with overlapping dates)
- [ ] **1.4.12** (BE) Wire booking status change signal to `send_booking_notification` Celery task
- [ ] **1.4.13** (BE) Implement dashboard bookings endpoint (GET `/dashboard/bookings/`) -- owner's incoming booking requests with status filter
- [ ] **1.4.14** (BE) Register Booking in Django admin

### 1.5 `chat` -- Real-time Messaging

Owns WebSocket chat rooms tied to bookings, message persistence, typing indicators, read receipts.

- [ ] **1.5.1** (BE) Create the `chat` app
- [ ] **1.5.2** (BE) Install and configure Django Channels with Redis channel layer in settings
- [ ] **1.5.3** (BE) Configure ASGI application in `config/asgi.py` with both HTTP and WebSocket routing
- [ ] **1.5.4** (BE) Implement `ChatRoom` model (uuid pk, booking FK one-to-one, created_at)
- [ ] **1.5.5** (BE) Implement `Message` model (uuid pk, room FK, sender FK to User, content text, is_read bool default False, created_at)
- [ ] **1.5.6** (BE) Create and run migrations
- [ ] **1.5.7** (BE) Implement Channels WebSocket consumer `ChatConsumer`:
  - `connect`: authenticate via JWT in query string, verify user is a booking participant, join channel group
  - `disconnect`: leave channel group
  - `receive`: dispatch by message type (chat.message, chat.typing, chat.read)
- [ ] **1.5.8** (BE) Implement `chat.message` handler: persist Message to DB, broadcast `new_message` event to room group
- [ ] **1.5.9** (BE) Implement `chat.typing` handler: broadcast `typing` event to room group (no persistence)
- [ ] **1.5.10** (BE) Implement `chat.read` handler: mark specified messages as read in DB, broadcast `read_receipt` event
- [ ] **1.5.11** (BE) Implement Channels URL routing: `ws/chat/{booking_id}/`
- [ ] **1.5.12** (BE) Implement message history REST endpoint (GET `/chat/rooms/{id}/messages/`) -- paginated, newest first
- [ ] **1.5.13** (BE) Implement chat room list REST endpoint (GET `/chat/rooms/`) -- rooms where user is a participant
- [ ] **1.5.14** (BE) Auto-create ChatRoom when booking transitions to CONFIRMED status (in the booking confirm signal/view)
- [ ] **1.5.15** (BE) Register ChatRoom and Message in Django admin

### 1.6 `payments` -- Stripe Mock and Invoices

Owns payment processing (mock), invoice PDF generation, invoice storage and download.

- [ ] **1.6.1** (BE) Create the `payments` app
- [ ] **1.6.2** (BE) Implement `Payment` model (uuid pk, booking FK one-to-one, amount decimal, stripe_payment_intent_id string, status enum PENDING/SUCCEEDED/FAILED, paid_at nullable datetime, timestamps)
- [ ] **1.6.3** (BE) Implement `Invoice` model (uuid pk, payment FK one-to-one, pdf_file FileField, generated_at datetime)
- [ ] **1.6.4** (BE) Create and run migrations
- [ ] **1.6.5** (BE) Implement `StripeMockService` class (Strategy pattern -- can be swapped for real Stripe later):
  - `create_payment_intent(amount)` -> returns dict with fake `id`, `client_secret`, `status`
  - `confirm_payment(intent_id)` -> returns dict with `status: succeeded`
- [ ] **1.6.6** (BE) Implement payment creation endpoint (POST `/payments/`) -- only for CONFIRMED bookings, creates Payment + mock intent
- [ ] **1.6.7** (BE) Implement payment confirmation endpoint (POST `/payments/{id}/confirm/`) -- updates Payment status, transitions Booking to PAID
- [ ] **1.6.8** (BE) Implement payment detail endpoint (GET `/payments/{id}/`) -- only booking participants
- [ ] **1.6.9** (BE) Implement HTML invoice template for WeasyPrint (booking details, equipment, dates, amount, company header)
- [ ] **1.6.10** (BE) Implement `generate_invoice` Celery task (render HTML template -> PDF via WeasyPrint, save to Invoice.pdf_file)
- [ ] **1.6.11** (BE) Wire payment confirmation to trigger `generate_invoice` + `send_payment_confirmation` tasks
- [ ] **1.6.12** (BE) Implement invoice download endpoint (GET `/payments/{id}/invoice/`) -- returns PDF file response
- [ ] **1.6.13** (BE) Register Payment and Invoice in Django admin

### 1.7 `notifications` -- Email Dispatch

Owns all Celery email tasks. Other apps dispatch tasks by name; this app owns rendering and sending. No models.

- [ ] **1.7.1** (BE) Create the `notifications` app
- [ ] **1.7.2** (BE) Implement `send_verification_email` Celery task (accepts user_id, renders verification email with token link, calls `send_mail`)
- [ ] **1.7.3** (BE) Implement `send_booking_notification` Celery task (accepts booking_id + status, sends appropriate email to tenant/owner depending on status change)
- [ ] **1.7.4** (BE) Implement `send_payment_confirmation` Celery task (accepts payment_id, sends receipt email to tenant)
- [ ] **1.7.5** (BE) Create email templates directory (`backend/templates/emails/`) with HTML templates for each email type
- [ ] **1.7.6** (BE) Configure Django email backend (console for dev, SMTP for prod via env vars)

---

## 2. Data Model Entities and Relations

### Entity List

| Entity                  | PK Type | Key Fields                                                              |
|------------------------|---------|-------------------------------------------------------------------------|
| **User**               | UUID    | email (unique), first_name, last_name, phone, role (TENANT/OWNER), is_email_verified, is_active |
| **EmailVerificationToken** | UUID | user FK, token (unique), expires_at, is_used                           |
| **Equipment**          | UUID    | owner FK->User, title, description, category (enum), daily_rate, location, is_available |
| **EquipmentPhoto**     | UUID    | equipment FK, image (file), sort_order, is_primary                     |
| **Booking**            | UUID    | equipment FK, tenant FK->User, start_date, end_date, total_price, status (enum), rejection_reason |
| **ChatRoom**           | UUID    | booking FK (one-to-one)                                                 |
| **Message**            | UUID    | room FK, sender FK->User, content, is_read, created_at                 |
| **Payment**            | UUID    | booking FK (one-to-one), amount, stripe_payment_intent_id, status (enum), paid_at |
| **Invoice**            | UUID    | payment FK (one-to-one), pdf_file (file), generated_at                 |

### Relations

- User 1--* Equipment (owner owns many equipment listings)
- User 1--* Booking (tenant has many bookings)
- Equipment 1--* EquipmentPhoto (equipment has many photos)
- Equipment 1--* Booking (equipment has many bookings)
- Booking 1--1 ChatRoom (each booking has one chat room, created on CONFIRMED)
- Booking 1--1 Payment (each booking has one payment)
- ChatRoom 1--* Message (chat room contains many messages)
- User 1--* Message (user sends many messages)
- Payment 1--1 Invoice (each payment generates one invoice)
- User 1--1 EmailVerificationToken (one active token per user)

### Enums

- **UserRole**: TENANT, OWNER
- **EquipmentCategory**: EXCAVATOR, CRANE, LOADER, BULLDOZER, TRUCK, FORKLIFT, GENERATOR, OTHER
- **BookingStatus**: DRAFT, PENDING, CONFIRMED, PAID, COMPLETED, REJECTED, CANCELLED
- **PaymentStatus**: PENDING, SUCCEEDED, FAILED

### Booking Status State Machine

```
DRAFT --> PENDING --> CONFIRMED --> PAID --> COMPLETED
                 \-> REJECTED
          PENDING --> CANCELLED (by tenant)
          CONFIRMED --> CANCELLED (by tenant)
```

### Design Decisions

- All models use UUID v4 primary keys (prevents enumeration, professional URLs)
- Single `role` field on User instead of Django Groups (two roles is too simple for groups/permissions)
- No soft deletes -- use `is_available` flag on Equipment
- `total_price` stored on Booking (calculated at creation: daily_rate * number of days)
- Draft bookings are ephemeral Redis keys, not DB records

---

## 3. API Endpoint Map

All endpoints prefixed with `/api/v1/`.

### 3.1 Auth -- `/api/v1/auth/`

| #   | Method | Endpoint                 | Description                   | Auth     | Role |
|-----|--------|--------------------------|-------------------------------|----------|------|
| 3.1.1 | POST | `/auth/register/`        | Register new user with role   | Public   | --   |
| 3.1.2 | POST | `/auth/login/`           | Obtain JWT token pair         | Public   | --   |
| 3.1.3 | POST | `/auth/token/refresh/`   | Refresh access token          | Public   | --   |
| 3.1.4 | POST | `/auth/verify-email/`    | Verify email with token       | Public   | --   |
| 3.1.5 | GET  | `/auth/me/`              | Get current user profile      | Required | Any  |
| 3.1.6 | PATCH| `/auth/me/`              | Update current user profile   | Required | Any  |

### 3.2 Equipment -- `/api/v1/equipment/`

| #   | Method | Endpoint                              | Description                           | Auth     | Role    |
|-----|--------|---------------------------------------|---------------------------------------|----------|---------|
| 3.2.1 | GET  | `/equipment/`                         | List/search with filters              | Public   | --      |
| 3.2.2 | GET  | `/equipment/{id}/`                    | Equipment detail with photos          | Public   | --      |
| 3.2.3 | GET  | `/equipment/{id}/calendar/`           | Booked date ranges                    | Public   | --      |
| 3.2.4 | POST | `/equipment/`                         | Create equipment listing              | Required | Owner   |
| 3.2.5 | PATCH| `/equipment/{id}/`                    | Update equipment                      | Required | Owner*  |
| 3.2.6 | DELETE| `/equipment/{id}/`                   | Delete equipment                      | Required | Owner*  |
| 3.2.7 | POST | `/equipment/{id}/photos/`             | Upload photos (multi-file)            | Required | Owner*  |
| 3.2.8 | DELETE| `/equipment/{id}/photos/{photo_id}/` | Delete a photo                        | Required | Owner*  |
| 3.2.9 | PATCH| `/equipment/{id}/photos/reorder/`     | Reorder photos                        | Required | Owner*  |

*Owner of the specific equipment item (object-level permission).

**Search query parameters:** `?category=`, `?location=`, `?min_price=`, `?max_price=`, `?available_from=`, `?available_to=`, `?search=` (full-text on title/description)

### 3.3 Bookings -- `/api/v1/bookings/`

| #   | Method | Endpoint                     | Description                        | Auth     | Role     |
|-----|--------|------------------------------|------------------------------------|----------|----------|
| 3.3.1 | POST | `/bookings/draft/`           | Create draft booking (Redis lock)  | Required | Tenant   |
| 3.3.2 | POST | `/bookings/`                 | Confirm draft -> PENDING booking   | Required | Tenant   |
| 3.3.3 | GET  | `/bookings/`                 | List my bookings (tenant or owner) | Required | Any      |
| 3.3.4 | GET  | `/bookings/{id}/`            | Booking detail                     | Required | Participant* |
| 3.3.5 | POST | `/bookings/{id}/confirm/`    | Owner confirms booking             | Required | Owner*   |
| 3.3.6 | POST | `/bookings/{id}/reject/`     | Owner rejects booking              | Required | Owner*   |
| 3.3.7 | POST | `/bookings/{id}/complete/`   | Owner marks as completed           | Required | Owner*   |
| 3.3.8 | POST | `/bookings/{id}/cancel/`     | Tenant cancels booking             | Required | Tenant*  |

*Participant in the specific booking (object-level permission).

### 3.4 Chat -- `/api/v1/chat/` + WebSocket

| #   | Method    | Endpoint                        | Description                   | Auth     | Role          |
|-----|-----------|---------------------------------|-------------------------------|----------|---------------|
| 3.4.1 | GET     | `/chat/rooms/`                  | List my chat rooms            | Required | Any           |
| 3.4.2 | GET     | `/chat/rooms/{id}/messages/`    | Message history (paginated)   | Required | Participant*  |
| 3.4.3 | WebSocket | `ws/chat/{booking_id}/`       | Real-time chat connection     | JWT (query) | Participant* |

**WebSocket message types:**

Client -> Server: `chat.message`, `chat.typing`, `chat.read`
Server -> Client: `new_message`, `typing`, `read_receipt`

### 3.5 Payments -- `/api/v1/payments/`

| #   | Method | Endpoint                      | Description                    | Auth     | Role          |
|-----|--------|-------------------------------|--------------------------------|----------|---------------|
| 3.5.1 | POST | `/payments/`                  | Create payment intent (mock)   | Required | Tenant*       |
| 3.5.2 | POST | `/payments/{id}/confirm/`     | Confirm payment (mock)         | Required | Tenant*       |
| 3.5.3 | GET  | `/payments/{id}/`             | Payment detail                 | Required | Participant*  |
| 3.5.4 | GET  | `/payments/{id}/invoice/`     | Download invoice PDF           | Required | Participant*  |

### 3.6 Owner Dashboard -- `/api/v1/dashboard/`

| #   | Method | Endpoint                    | Description                          | Auth     | Role  |
|-----|--------|-----------------------------|--------------------------------------|----------|-------|
| 3.6.1 | GET  | `/dashboard/stats/`         | Income, idle, booking count summary  | Required | Owner |
| 3.6.2 | GET  | `/dashboard/bookings/`      | Owner's booking requests (filtered)  | Required | Owner |
| 3.6.3 | GET  | `/dashboard/equipment/`     | Owner's equipment list               | Required | Owner |

Note: These endpoints are additional views in `equipment` and `bookings` apps, not a separate Django app.

---

## 4. Frontend Pages and Components

### 4.1 Route-Level Pages

| #   | Route                        | Page Component        | Auth   | Description                            |
|-----|------------------------------|-----------------------|--------|----------------------------------------|
| 4.1.1 | `/`                        | `HomePage`            | Public | Landing page with hero + search bar    |
| 4.1.2 | `/login`                   | `LoginPage`           | Public | Login form (email + password)          |
| 4.1.3 | `/register`                | `RegisterPage`        | Public | Registration with role selection       |
| 4.1.4 | `/verify-email/:token`     | `VerifyEmailPage`     | Public | Email verification handler             |
| 4.1.5 | `/equipment`               | `EquipmentListPage`   | Public | Search results with filter sidebar     |
| 4.1.6 | `/equipment/:id`           | `EquipmentDetailPage` | Public | Detail + gallery + calendar + book     |
| 4.1.7 | `/bookings`                | `BookingsListPage`    | Auth   | My bookings with status filter tabs    |
| 4.1.8 | `/bookings/:id`            | `BookingDetailPage`   | Auth   | Booking detail + chat + payment        |
| 4.1.9 | `/dashboard`               | `DashboardPage`       | Owner  | Stats cards + equipment + bookings     |
| 4.1.10 | `/dashboard/equipment/new`| `EquipmentFormPage`   | Owner  | Create equipment form                  |
| 4.1.11 | `/dashboard/equipment/:id`| `EquipmentFormPage`   | Owner  | Edit equipment form                    |

### 4.2 Feature Module Structure

Each feature folder under `frontend/src/features/{feature}/`:

```
features/{feature}/
|-- api.ts              # RTK Query endpoint definitions
|-- types.ts            # TypeScript interfaces for the domain
|-- components/         # Feature-specific UI components
|-- hooks/              # Feature-specific custom hooks
|-- slices/             # Redux slices (if local state beyond RTK Query)
```

Feature modules: `auth`, `equipment`, `bookings`, `chat`, `dashboard`, `payments`

### 4.3 Implementation Checklist -- Pages

- [ ] **4.3.1** (FE) Create React project with Vite + TypeScript template inside `frontend/`
- [ ] **4.3.2** (FE) Install and configure Tailwind CSS
- [ ] **4.3.3** (FE) Install and configure React Router v6 with route definitions
- [ ] **4.3.4** (FE) Install and configure Redux Toolkit + RTK Query
- [ ] **4.3.5** (FE) Create base RTK Query API (`frontend/src/app/api.ts`) with JWT auth header injection via `prepareHeaders`
- [ ] **4.3.6** (FE) Create `authSlice` with token storage in localStorage, login/logout reducers
- [ ] **4.3.7** (FE) Build `Navbar` component (logo, nav links, auth state: login/register buttons or user dropdown)
- [ ] **4.3.8** (FE) Build `ProtectedRoute` component (redirects to `/login` if unauthenticated)
- [ ] **4.3.9** (FE) Build `RoleGuard` component (renders children only if user has required role)
- [ ] **4.3.10** (FE) Build `LoginPage` (email, password, submit, error display)
- [ ] **4.3.11** (FE) Build `RegisterPage` (email, password, confirm, first name, last name, role radio TENANT/OWNER)
- [ ] **4.3.12** (FE) Build `VerifyEmailPage` (reads token from URL, calls verify endpoint, shows success/error)
- [ ] **4.3.13** (FE) Build `HomePage` (hero section, `SearchBar` component, featured equipment preview)
- [ ] **4.3.14** (FE) Build `SearchBar` component with 300ms debounce using `useDeferredValue` or custom hook
- [ ] **4.3.15** (FE) Build `FilterSidebar` component (category checkboxes, price range inputs, date range picker)
- [ ] **4.3.16** (FE) Build `EquipmentListPage` (search bar + filter sidebar + equipment cards grid + pagination)
- [ ] **4.3.17** (FE) Build `PhotoGallery` component (lightbox-style image gallery with thumbnails)
- [ ] **4.3.18** (FE) Build `OccupancyCalendar` component (calendar view showing booked/available dates)
- [ ] **4.3.19** (FE) Build `EquipmentDetailPage` (photo gallery, description, daily rate, occupancy calendar, "Book Now" date picker + submit)
- [ ] **4.3.20** (FE) Build `StatusBadge` component (colored badge for booking/payment status)
- [ ] **4.3.21** (FE) Build `BookingsListPage` (list with status filter tabs: All/Pending/Confirmed/Paid/Completed)
- [ ] **4.3.22** (FE) Build `BookingDetailPage` layout (booking info, status actions, payment section, chat section)
- [ ] **4.3.23** (FE) Build payment flow in `BookingDetailPage` (pay button -> confirm -> show invoice download)
- [ ] **4.3.24** (FE) Build `ChatWindow` component (message list, input field, send button, WebSocket connection)
- [ ] **4.3.25** (FE) Implement typing indicator in `ChatWindow` ("User is typing..." with debounce)
- [ ] **4.3.26** (FE) Implement read receipts in `ChatWindow` (checkmarks on sent messages)
- [ ] **4.3.27** (FE) Integrate `ChatWindow` into `BookingDetailPage` (only visible when ChatRoom exists)
- [ ] **4.3.28** (FE) Build `DashboardPage` layout (stats cards row, equipment section, bookings section)
- [ ] **4.3.29** (FE) Build `StatsChart` components (income over time line chart, idle days bar chart) -- use Recharts or Chart.js
- [ ] **4.3.30** (FE) Build `DragDropUpload` component (multi-file drag-and-drop with preview thumbnails, reorder)
- [ ] **4.3.31** (FE) Build `EquipmentFormPage` (title, description, category select, daily rate, location, photo upload section using `DragDropUpload`)
- [ ] **4.3.32** (FE) Build booking management section in `DashboardPage` (incoming requests list with approve/reject buttons)
- [ ] **4.3.33** (FE) Build shared `Pagination` component
- [ ] **4.3.34** (FE) Build shared `EmptyState` component (placeholder for empty lists)
- [ ] **4.3.35** (FE) Build shared `LoadingSpinner` component
- [ ] **4.3.36** (FE) Build shared `ConfirmDialog` modal component

### 4.4 State Management Strategy

- **Server state**: RTK Query for all API data (caching, invalidation, loading states)
- **Auth state**: Redux slice (`authSlice`) with JWT tokens + user info persisted to localStorage
- **WebSocket state**: Local component state via `useRef` + `useState` in `ChatWindow` (not Redux)
- **Form state**: React Hook Form for all forms (install `react-hook-form` + `@hookform/resolvers` + `zod`)
- **URL state**: React Router search params for search/filter state (shareable URLs)

### 4.5 RTK Query API Definitions

- [ ] **4.5.1** (FE) Create `features/auth/api.ts` -- register, login, refreshToken, verifyEmail, getMe, updateMe
- [ ] **4.5.2** (FE) Create `features/equipment/api.ts` -- listEquipment, getEquipment, getCalendar, createEquipment, updateEquipment, deleteEquipment, uploadPhotos, deletePhoto, reorderPhotos
- [ ] **4.5.3** (FE) Create `features/bookings/api.ts` -- createDraft, createBooking, listBookings, getBooking, confirmBooking, rejectBooking, cancelBooking, completeBooking
- [ ] **4.5.4** (FE) Create `features/chat/api.ts` -- listRooms, getMessages
- [ ] **4.5.5** (FE) Create `features/payments/api.ts` -- createPayment, confirmPayment, getPayment, downloadInvoice
- [ ] **4.5.6** (FE) Create `features/dashboard/api.ts` -- getStats, getDashboardEquipment, getDashboardBookings

---

## 5. Docker Compose Services

### 5.1 Service Topology

8 services total:

| #   | Service          | Base Image / Build Context    | Exposed Port | Depends On      | Purpose                          |
|-----|------------------|-------------------------------|--------------|-----------------|----------------------------------|
| 5.1.1 | `db`           | `postgres:15-alpine`          | 5432         | --              | PostgreSQL database              |
| 5.1.2 | `redis`        | `redis:7-alpine`              | 6379         | --              | Celery broker + cache + Channels |
| 5.1.3 | `backend`      | Build `docker/backend/`       | 8000         | db, redis       | Django via Daphne (HTTP + WS)    |
| 5.1.4 | `celery-worker`| Same image as backend         | --           | db, redis       | Celery worker processes          |
| 5.1.5 | `celery-beat`  | Same image as backend         | --           | redis           | Celery periodic task scheduler   |
| 5.1.6 | `flower`       | Same image as backend         | 5555         | redis           | Celery monitoring UI             |
| 5.1.7 | `frontend`     | Build `docker/frontend/`      | 3000         | --              | Vite dev server (dev) / Nginx (prod) |
| 5.1.8 | `nginx`        | Build `docker/nginx/`         | 80           | backend, frontend | Reverse proxy                   |

### 5.2 Implementation Checklist

- [ ] **5.2.1** (INFRA) Create `docker/backend/Dockerfile`:
  - Base: `python:3.11-slim`
  - Install system deps (PostgreSQL client, WeasyPrint deps: `libpango`, `libcairo`, `libgdk-pixbuf`)
  - Copy requirements, `pip install`
  - Copy source code
  - Expose 8000
  - CMD: `daphne -b 0.0.0.0 -p 8000 config.asgi:application`

- [ ] **5.2.2** (INFRA) Create `docker/backend/entrypoint.sh`:
  - Wait for PostgreSQL to be ready
  - Run `python manage.py migrate`
  - Run `python manage.py collectstatic --noinput`
  - Execute CMD

- [ ] **5.2.3** (INFRA) Create `docker/frontend/Dockerfile`:
  - Base: `node:20-alpine`
  - Copy package.json + lock, `npm install`
  - Copy source code
  - Dev: CMD `npm run dev -- --host 0.0.0.0`
  - Prod (multi-stage): build with Vite, serve with Nginx

- [ ] **5.2.4** (INFRA) Create `docker/nginx/nginx.conf`:
  - `/api/` and `/admin/` -> proxy to `backend:8000`
  - `/ws/` -> proxy to `backend:8000` with WebSocket upgrade headers
  - `/media/` -> serve from shared volume
  - `/*` -> proxy to `frontend:3000`

- [ ] **5.2.5** (INFRA) Create `docker/nginx/Dockerfile` (FROM `nginx:alpine`, copy config)

- [ ] **5.2.6** (INFRA) Create `docker-compose.yml` with all 8 services, networks, volumes (`postgres_data`, `media_data`)

- [ ] **5.2.7** (INFRA) Create `docker-compose.override.yml` for dev:
  - Backend: mount `./backend` as volume for hot reload
  - Frontend: mount `./frontend/src` as volume for HMR
  - Backend env: `DEBUG=1`

- [ ] **5.2.8** (INFRA) Create `.env.example` with all required environment variables:
  - `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `DATABASE_URL`
  - `REDIS_URL`
  - `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`
  - `CELERY_BROKER_URL`
  - `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`
  - `FRONTEND_URL` (for email verification links)

- [ ] **5.2.9** (INFRA) Create `Makefile` with convenience commands:
  - `make up` -- docker-compose up -d
  - `make down` -- docker-compose down
  - `make build` -- docker-compose build
  - `make test-be` -- run backend pytest inside container
  - `make test-fe` -- run frontend vitest inside container
  - `make migrate` -- run Django migrations
  - `make shell` -- Django shell inside container
  - `make logs` -- docker-compose logs -f
  - `make seed` -- run seed data management command

- [ ] **5.2.10** (INFRA) Verify `docker-compose up` starts all services without errors

---

## 6. GitHub Actions CI Pipeline

### 6.1 Pipeline Structure

File: `.github/workflows/ci.yml`

5 parallel jobs:

| #   | Job                | Runner         | Services        | Purpose                                    |
|-----|--------------------|----------------|-----------------|--------------------------------------------|
| 6.1.1 | `backend-lint`   | ubuntu-latest  | --              | Ruff linting + formatting check            |
| 6.1.2 | `backend-test`   | ubuntu-latest  | PostgreSQL, Redis | pytest with coverage                     |
| 6.1.3 | `frontend-lint`  | ubuntu-latest  | --              | ESLint + TypeScript type checking          |
| 6.1.4 | `frontend-test`  | ubuntu-latest  | --              | Vitest unit tests                          |
| 6.1.5 | `frontend-build` | ubuntu-latest  | --              | Vite production build                      |

### 6.2 Implementation Checklist

- [ ] **6.2.1** (INFRA) Create `.github/workflows/ci.yml` with trigger on push to `master`/`develop` and PR to `master`

- [ ] **6.2.2** (INFRA) Implement `backend-lint` job:
  - Checkout
  - Setup Python 3.11
  - Install `ruff`
  - Run `ruff check backend/`
  - Run `ruff format --check backend/`

- [ ] **6.2.3** (INFRA) Implement `backend-test` job:
  - Services: `postgres:15-alpine` (health check), `redis:7-alpine`
  - Checkout
  - Setup Python 3.11
  - Cache pip dependencies
  - Install `requirements/test.txt`
  - Run `pytest --cov=apps --cov-report=xml --cov-fail-under=80`
  - Upload coverage report as artifact
  - Env: `DATABASE_URL=postgres://...`, `REDIS_URL=redis://...`, `DJANGO_SETTINGS_MODULE=config.settings.test`

- [ ] **6.2.4** (INFRA) Implement `frontend-lint` job:
  - Checkout
  - Setup Node 20
  - Cache node_modules
  - `npm ci`
  - `npx eslint src/`
  - `npx tsc --noEmit`

- [ ] **6.2.5** (INFRA) Implement `frontend-test` job:
  - Checkout
  - Setup Node 20
  - Cache node_modules
  - `npm ci`
  - `npx vitest run --coverage`

- [ ] **6.2.6** (INFRA) Implement `frontend-build` job:
  - Checkout
  - Setup Node 20
  - `npm ci`
  - `npx vite build`

- [ ] **6.2.7** (INFRA) Create `backend/pytest.ini` (or `pyproject.toml` section):
  - `DJANGO_SETTINGS_MODULE = config.settings.test`
  - `python_files = test_*.py`
  - `addopts = -v --tb=short`

- [ ] **6.2.8** (INFRA) Create `backend/conftest.py` with shared fixtures (see section 7)

- [ ] **6.2.9** (BE) Create `config/settings/test.py`:
  - Inherit from `base.py`
  - Use in-memory file storage for media
  - Use console email backend
  - Set `CELERY_TASK_ALWAYS_EAGER = True` (tasks execute synchronously in tests)
  - Disable throttling
  - Use faster password hasher (`MD5PasswordHasher`)

---

## 7. Test Architecture

### 7.1 Testing Stack

| Layer    | Tools                                                                |
|----------|----------------------------------------------------------------------|
| Backend  | `pytest`, `pytest-django`, `pytest-asyncio`, `factory-boy`, `channels[tests]`, `pytest-cov` |
| Frontend | `vitest`, `@testing-library/react`, `@testing-library/user-event`, `msw` (Mock Service Worker) |
| CI       | GitHub Actions running both suites against real PostgreSQL + Redis   |

### 7.2 Backend Test Directory Structure

```
backend/
|-- conftest.py                          # Shared fixtures and factories
|-- apps/
|   |-- accounts/tests/
|   |   |-- __init__.py
|   |   |-- test_models.py               # User model, EmailVerificationToken model
|   |   |-- test_serializers.py          # Registration serializer validation
|   |   |-- test_views.py               # All auth endpoints
|   |-- equipment/tests/
|   |   |-- __init__.py
|   |   |-- test_models.py               # Equipment, EquipmentPhoto models
|   |   |-- test_views.py               # CRUD + search/filter endpoints
|   |   |-- test_filters.py             # Date-range availability filter logic
|   |-- bookings/tests/
|   |   |-- __init__.py
|   |   |-- test_models.py               # Booking model, status transitions
|   |   |-- test_views.py               # All booking endpoints
|   |   |-- test_services.py            # DraftBookingService (Redis)
|   |-- chat/tests/
|   |   |-- __init__.py
|   |   |-- test_models.py               # ChatRoom, Message models
|   |   |-- test_consumers.py           # WebSocket consumer (channels.testing)
|   |   |-- test_views.py               # Message history, room list
|   |-- payments/tests/
|   |   |-- __init__.py
|   |   |-- test_models.py               # Payment, Invoice models
|   |   |-- test_views.py               # Payment create/confirm, invoice download
|   |   |-- test_services.py            # StripeMockService
|   |   |-- test_tasks.py               # generate_invoice Celery task
|   |-- notifications/tests/
|   |   |-- __init__.py
|   |   |-- test_tasks.py               # All email Celery tasks
```

### 7.3 Shared Test Fixtures (`conftest.py`)

- [ ] **7.3.1** (BE) Implement `UserFactory` (factory-boy) -- configurable role, default TENANT
- [ ] **7.3.2** (BE) Implement `EquipmentFactory` -- auto-creates Owner user
- [ ] **7.3.3** (BE) Implement `EquipmentPhotoFactory` -- creates photo for equipment
- [ ] **7.3.4** (BE) Implement `BookingFactory` -- auto-creates equipment + tenant
- [ ] **7.3.5** (BE) Implement `ChatRoomFactory` -- auto-creates booking
- [ ] **7.3.6** (BE) Implement `MessageFactory` -- creates message in a room
- [ ] **7.3.7** (BE) Implement `PaymentFactory` -- creates payment for a booking
- [ ] **7.3.8** (BE) Implement `InvoiceFactory` -- creates invoice for a payment
- [ ] **7.3.9** (BE) Implement pytest fixtures: `api_client`, `tenant_user`, `owner_user`, `authenticated_client(user)`, `sample_equipment`, `sample_booking`

### 7.4 What to Test Per Module

#### 7.4.1 Accounts (Auth and RBAC)

**Unit tests (`test_models.py`, `test_serializers.py`):**
- [ ] User creation with TENANT role
- [ ] User creation with OWNER role
- [ ] Email uniqueness constraint
- [ ] `is_email_verified` defaults to False
- [ ] Registration serializer: valid data produces valid user
- [ ] Registration serializer: missing required fields
- [ ] Registration serializer: duplicate email
- [ ] Registration serializer: password mismatch
- [ ] Registration serializer: invalid role value
- [ ] EmailVerificationToken: token generation, expiry check

**Integration tests (`test_views.py`):**
- [ ] POST `/auth/register/` returns 201, creates user, dispatches email task (mock Celery)
- [ ] POST `/auth/login/` returns JWT pair for valid credentials
- [ ] POST `/auth/login/` returns 401 for invalid credentials
- [ ] POST `/auth/login/` returns 401 for unverified email (if enforced)
- [ ] POST `/auth/token/refresh/` returns new access token
- [ ] POST `/auth/token/refresh/` returns 401 for expired refresh token
- [ ] POST `/auth/verify-email/` returns 200 for valid token
- [ ] POST `/auth/verify-email/` returns 400 for expired/used token
- [ ] GET `/auth/me/` returns user profile when authenticated
- [ ] GET `/auth/me/` returns 401 when unauthenticated
- [ ] PATCH `/auth/me/` updates allowed fields
- [ ] PATCH `/auth/me/` ignores role change attempts
- [ ] Permission enforcement: Owner-only endpoint rejects Tenant (403)
- [ ] Permission enforcement: Tenant-only endpoint rejects Owner (403)

#### 7.4.2 Equipment

**Unit tests (`test_models.py`):**
- [ ] Equipment string representation
- [ ] Equipment `daily_rate` positive decimal validation
- [ ] EquipmentPhoto sort ordering
- [ ] EquipmentPhoto `is_primary` behavior

**Integration tests (`test_views.py`, `test_filters.py`):**
- [ ] GET `/equipment/` returns paginated results
- [ ] GET `/equipment/?search=crane` filters by title/description
- [ ] GET `/equipment/?category=EXCAVATOR` filters by category
- [ ] GET `/equipment/?min_price=100&max_price=500` filters by price range
- [ ] GET `/equipment/?available_from=...&available_to=...` excludes booked equipment
- [ ] GET `/equipment/{id}/` returns equipment with nested photos
- [ ] GET `/equipment/{id}/calendar/` returns booked date ranges
- [ ] POST `/equipment/` as Owner creates equipment (201)
- [ ] POST `/equipment/` as Tenant returns 403
- [ ] PATCH `/equipment/{id}/` as equipment owner updates it
- [ ] PATCH `/equipment/{id}/` as different owner returns 403
- [ ] DELETE `/equipment/{id}/` as equipment owner deletes it
- [ ] POST `/equipment/{id}/photos/` uploads multiple photos
- [ ] DELETE `/equipment/{id}/photos/{photo_id}/` removes photo

#### 7.4.3 Bookings

**Unit tests (`test_models.py`, `test_services.py`):**
- [ ] Booking `total_price` calculation (daily_rate * number of days)
- [ ] Valid status transitions accepted
- [ ] Invalid status transitions rejected
- [ ] DraftBookingService: creates Redis key with correct format
- [ ] DraftBookingService: TTL is 15 minutes
- [ ] DraftBookingService: `is_locked` returns True when key exists
- [ ] DraftBookingService: `is_locked` returns False after TTL expiry

**Integration tests (`test_views.py`):**
- [ ] POST `/bookings/draft/` creates Redis lock, returns draft info
- [ ] POST `/bookings/draft/` returns 409 if equipment already locked by another user
- [ ] POST `/bookings/` converts valid draft to PENDING booking
- [ ] POST `/bookings/` returns 400 if draft expired
- [ ] POST `/bookings/` rejects overlapping dates for same equipment
- [ ] POST `/bookings/{id}/confirm/` as Owner transitions PENDING -> CONFIRMED
- [ ] POST `/bookings/{id}/confirm/` as Tenant returns 403
- [ ] POST `/bookings/{id}/reject/` requires rejection_reason
- [ ] POST `/bookings/{id}/cancel/` allowed from PENDING
- [ ] POST `/bookings/{id}/cancel/` allowed from CONFIRMED
- [ ] POST `/bookings/{id}/cancel/` rejected from PAID (400)
- [ ] POST `/bookings/{id}/complete/` allowed from PAID only
- [ ] GET `/bookings/` Tenant sees own bookings only
- [ ] GET `/bookings/` Owner sees bookings for their equipment only
- [ ] GET `/bookings/{id}/` only accessible by participants

#### 7.4.4 Chat (WebSocket)

**Unit tests (`test_models.py`):**
- [ ] Message `is_read` defaults to False
- [ ] Messages ordered by `created_at`
- [ ] ChatRoom one-to-one with Booking

**WebSocket tests (`test_consumers.py` -- using `channels.testing.WebsocketCommunicator`):**
- [ ] Authenticated booking participant can connect
- [ ] Unauthenticated connection is rejected
- [ ] Non-participant connection is rejected
- [ ] Sending `chat.message` persists message to DB
- [ ] Sending `chat.message` broadcasts `new_message` to room
- [ ] Sending `chat.typing` broadcasts typing event (not persisted)
- [ ] Sending `chat.read` marks messages as read in DB
- [ ] Sending `chat.read` broadcasts `read_receipt` to room
- [ ] Clean disconnect without errors

**Integration tests (`test_views.py`):**
- [ ] GET `/chat/rooms/` returns rooms where user is a participant
- [ ] GET `/chat/rooms/{id}/messages/` returns paginated messages
- [ ] GET `/chat/rooms/{id}/messages/` returns 403 for non-participant

#### 7.4.5 Payments

**Unit tests (`test_models.py`, `test_services.py`):**
- [ ] Payment status transitions: PENDING -> SUCCEEDED, PENDING -> FAILED
- [ ] StripeMockService `create_payment_intent` returns expected dict shape
- [ ] StripeMockService `confirm_payment` returns succeeded status
- [ ] Invoice `generated_at` is set

**Integration tests (`test_views.py`):**
- [ ] POST `/payments/` creates Payment for CONFIRMED booking
- [ ] POST `/payments/` returns 400 for non-CONFIRMED booking
- [ ] POST `/payments/{id}/confirm/` updates Payment to SUCCEEDED
- [ ] POST `/payments/{id}/confirm/` transitions Booking to PAID
- [ ] POST `/payments/{id}/confirm/` triggers invoice generation task (mock)
- [ ] GET `/payments/{id}/` accessible by participants only
- [ ] GET `/payments/{id}/invoice/` returns PDF file
- [ ] GET `/payments/{id}/invoice/` returns 404 if not yet generated
- [ ] GET `/payments/{id}/invoice/` returns 403 for non-participant

**Celery task tests (`test_tasks.py`):**
- [ ] `generate_invoice` produces a valid PDF file
- [ ] `generate_invoice` saves file to Invoice record
- [ ] `generate_invoice` PDF contains correct booking details

#### 7.4.6 Notifications

**Celery task tests (`test_tasks.py`):**
- [ ] `send_verification_email` calls `send_mail` with correct subject, recipient, body
- [ ] `send_booking_notification` sends correct email for each status change type
- [ ] `send_payment_confirmation` calls `send_mail` with receipt details
- [ ] All tasks handle missing/invalid user email gracefully (no crash)

### 7.5 Frontend Test Coverage

**Testing approach:** Vitest + React Testing Library + MSW for API mocking.

**Unit tests (component rendering and behavior):**
- [ ] `LoginPage`: form validation, submit handler, error display
- [ ] `RegisterPage`: role selection radio, form validation
- [ ] `SearchBar`: debounce behavior (types -> waits 300ms -> triggers callback)
- [ ] `FilterSidebar`: filter state changes propagate correctly
- [ ] `PhotoGallery`: navigation between images, thumbnail selection
- [ ] `OccupancyCalendar`: booked dates displayed as unavailable, selectable dates work
- [ ] `StatusBadge`: renders correct color/text for each status
- [ ] `DragDropUpload`: file handling, preview thumbnails, reorder
- [ ] `StatsChart`: renders with mock data without errors
- [ ] `ChatWindow`: renders message list, input field, send button
- [ ] `ChatWindow`: displays typing indicator when active
- [ ] `ProtectedRoute`: redirects unauthenticated users to `/login`
- [ ] `RoleGuard`: hides content for wrong role, shows for correct role
- [ ] `Pagination`: renders correct page numbers, triggers page change

**Integration tests (with MSW API mocking):**
- [ ] Auth flow: register -> show success -> login -> redirected to home with auth state
- [ ] Equipment search: type query -> debounce -> API call -> results rendered
- [ ] Booking flow: select dates -> create draft -> confirm -> PENDING booking shown
- [ ] Payment flow: click pay -> confirm -> status updates to PAID
- [ ] RTK Query cache invalidation: after booking creation, relevant queries refetch

### 7.6 CI Test Execution Summary

What CI runs on every push/PR:

| Job              | Commands                                              | Threshold       |
|------------------|-------------------------------------------------------|-----------------|
| backend-lint     | `ruff check`, `ruff format --check`                   | Zero violations |
| backend-test     | `pytest --cov=apps --cov-fail-under=80`               | 80% coverage    |
| frontend-lint    | `eslint src/`, `tsc --noEmit`                         | Zero violations |
| frontend-test    | `vitest run --coverage`                                | Pass all tests  |
| frontend-build   | `vite build`                                          | Build succeeds  |

---

## Phase Execution Order

For development, follow this order (each phase builds on the previous):

1. **Phase 0: Scaffolding** -- repo structure, Docker, CI stubs, Django/React project init
2. **Phase 1: Core + Auth** -- base models, User model, JWT, email verification, auth UI
3. **Phase 2: Equipment** -- models, CRUD, search/filter, equipment list/detail UI
4. **Phase 3: Bookings + Calendar** -- booking lifecycle, Redis draft, calendar, booking UI
5. **Phase 4: Owner Dashboard** -- stats endpoints, dashboard UI, equipment management UI
6. **Phase 5: Chat** -- Django Channels, WebSocket consumer, ChatWindow UI
7. **Phase 6: Payments + Invoices** -- Stripe mock, WeasyPrint PDF, payment UI
8. **Phase 7: Polish** -- pagination everywhere, error handling, throttling, CORS, admin, health check, README

Each phase ends with writing tests for that phase's functionality. Tests are cumulative -- later phases must not break earlier tests.

---

*Plan created: 2026-03-17*
*Scope: Full architecture for HavyRentPro portfolio project*
