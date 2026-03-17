# HavyRentPro

A full-stack heavy equipment rental platform built as a portfolio project. Equipment owners list machinery, tenants search and book it, and the platform manages the full lifecycle from inquiry to paid invoice — including real-time chat between parties.

![Python](https://img.shields.io/badge/Python-3.11-blue)
![Django](https://img.shields.io/badge/Django-4.x-green)
![React](https://img.shields.io/badge/React-18-61dafb)
![TypeScript](https://img.shields.io/badge/TypeScript-5.x-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791)
![Redis](https://img.shields.io/badge/Redis-7-red)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.14, Django 6.x, Django REST Framework |
| Auth | SimpleJWT (access 30 min, refresh 7 days, rotate enabled) |
| Real-time | Django Channels 4.x, Redis channel layer |
| Task Queue | Celery + Redis broker, Celery Beat, Flower |
| PDF Generation | WeasyPrint |
| Database | PostgreSQL 15 |
| Cache / Broker | Redis 7 |
| Frontend | React 18, TypeScript, Vite, Tailwind CSS |
| State Management | Redux Toolkit + RTK Query |
| Forms | React Hook Form + Zod |
| Charts | Recharts |
| Payments | Stripe mock (Strategy pattern, swappable for real Stripe) |
| Testing (BE) | pytest, pytest-django, pytest-asyncio, factory-boy, channels[tests], pytest-cov |
| Testing (FE) | Vitest, React Testing Library, Mock Service Worker (MSW) |
| Linting (BE) | Ruff |
| Linting (FE) | ESLint + TypeScript compiler |
| Infrastructure | Docker Compose, Nginx, GitHub Actions CI |

---

## Architecture

### Django App Structure

Seven domain apps under `backend/apps/`, organized by domain rather than technical layer:

| App | Responsibility |
|---|---|
| `core` | Abstract base models (`BaseModel`), shared DRF permission classes, pagination, custom exception handler, shared enums. No database tables. |
| `accounts` | Custom User model, JWT auth, email verification, user profiles. |
| `equipment` | Equipment listings, photos, search/filter, occupancy calendar, owner dashboard stats and equipment endpoints. |
| `bookings` | Booking creation, Redis draft reservation, status state machine, dashboard booking management. |
| `chat` | WebSocket chat rooms tied to bookings, message persistence, typing indicators, read receipts. |
| `payments` | Stripe mock service, payment creation and confirmation, WeasyPrint PDF invoice generation and download. |
| `notifications` | All Celery email tasks — verification, booking status changes, payment receipts. No models. |

### Data Model Entities and Relations

| Entity | PK | Key Fields |
|---|---|---|
| `User` | UUID | email (unique login), first_name, last_name, phone, role (TENANT/OWNER), is_email_verified, is_active |
| `EmailVerificationToken` | UUID | user FK, token (unique), expires_at, is_used |
| `Equipment` | UUID | owner FK->User, title, description, category (enum), daily_rate, location, is_available |
| `EquipmentPhoto` | UUID | equipment FK, image (file), sort_order, is_primary |
| `Booking` | UUID | equipment FK, tenant FK->User, start_date, end_date, total_price, status (enum), rejection_reason |
| `ChatRoom` | UUID | booking FK (one-to-one, created on CONFIRMED) |
| `Message` | UUID | room FK, sender FK->User, content, is_read, created_at |
| `Payment` | UUID | booking FK (one-to-one), amount, stripe_payment_intent_id, status (enum), paid_at |
| `Invoice` | UUID | payment FK (one-to-one), pdf_file (file), generated_at |

**Relations:**
- User 1--* Equipment (owner has many listings)
- User 1--* Booking (tenant has many bookings)
- Equipment 1--* EquipmentPhoto
- Equipment 1--* Booking
- Booking 1--1 ChatRoom
- Booking 1--1 Payment
- ChatRoom 1--* Message
- User 1--* Message (sender)
- Payment 1--1 Invoice

**Enums:**
- `UserRole`: TENANT, OWNER
- `EquipmentCategory`: EXCAVATOR, CRANE, LOADER, BULLDOZER, TRUCK, FORKLIFT, GENERATOR, OTHER
- `BookingStatus`: DRAFT, PENDING, CONFIRMED, PAID, COMPLETED, REJECTED, CANCELLED
- `PaymentStatus`: PENDING, SUCCEEDED, FAILED

**Booking State Machine:**

```
DRAFT --> PENDING --> CONFIRMED --> PAID --> COMPLETED
                  \-> REJECTED
         PENDING --> CANCELLED  (by tenant)
         CONFIRMED --> CANCELLED (by tenant)
```

**Design decisions:**
- All PKs are UUID v4 — prevents enumeration attacks and produces clean URLs
- Single `role` field on User instead of Django Groups — two roles is too simple to warrant the Groups abstraction
- No soft deletes — Equipment uses `is_available` flag
- `total_price` is stored on Booking at creation (daily_rate x days), not recalculated later
- Draft bookings are ephemeral Redis keys (`draft:{equipment_id}:{user_id}`, 15-min TTL), not DB rows

### Docker Compose Services

8 services:

| Service | Image / Build | Port | Purpose |
|---|---|---|---|
| `db` | postgres:15-alpine | 5432 | PostgreSQL database |
| `redis` | redis:7-alpine | 6379 | Celery broker + cache + Channels layer |
| `backend` | Build `docker/backend/` | 8000 | Django via Daphne (HTTP + WebSocket) |
| `celery-worker` | Same image as backend | — | Celery worker processes |
| `celery-beat` | Same image as backend | — | Periodic task scheduler |
| `flower` | Same image as backend | 5555 | Celery monitoring UI |
| `frontend` | Build `docker/frontend/` | 3000 | Vite dev server (dev) / Nginx (prod) |
| `nginx` | Build `docker/nginx/` | 80 | Reverse proxy for all traffic |

Volumes: `postgres_data`, `media_data`

Nginx routing:
- `/api/` and `/admin/` proxied to `backend:8000`
- `/ws/` proxied to `backend:8000` with WebSocket upgrade headers
- `/media/` served from shared volume
- `/*` proxied to `frontend:3000`

### Frontend Page Structure

| Route | Page Component | Auth | Description |
|---|---|---|---|
| `/` | `HomePage` | Public | Landing page with hero section and search bar |
| `/login` | `LoginPage` | Public | Email + password login form |
| `/register` | `RegisterPage` | Public | Registration with role selection (TENANT/OWNER) |
| `/verify-email/:token` | `VerifyEmailPage` | Public | Email verification handler |
| `/equipment` | `EquipmentListPage` | Public | Search results with filter sidebar and pagination |
| `/equipment/:id` | `EquipmentDetailPage` | Public | Gallery, description, occupancy calendar, booking date picker |
| `/bookings` | `BookingsListPage` | Auth | My bookings with status filter tabs |
| `/bookings/:id` | `BookingDetailPage` | Auth | Booking info, actions, payment section, chat window |
| `/dashboard` | `DashboardPage` | Owner | Stats cards, equipment list, incoming booking requests |
| `/dashboard/equipment/new` | `EquipmentFormPage` | Owner | Create equipment listing |
| `/dashboard/equipment/:id` | `EquipmentFormPage` | Owner | Edit equipment listing |

Frontend feature modules under `frontend/src/features/{feature}/`: `auth`, `equipment`, `bookings`, `chat`, `dashboard`, `payments`

Each feature module contains: `api.ts` (RTK Query endpoints), `types.ts` (TypeScript interfaces), `components/`, `hooks/`, and optionally `slices/`.

State management strategy:
- **Server state**: RTK Query for all API data (caching, invalidation, loading states)
- **Auth state**: Redux `authSlice` with JWT tokens persisted to localStorage
- **WebSocket state**: Local component state via `useRef` + `useState` in `ChatWindow` (not Redux)
- **Form state**: React Hook Form + Zod for all forms
- **URL state**: React Router search params for search/filter state (shareable URLs)

---

## Implementation Roadmap

Tasks are labeled `(BE)` backend, `(FE)` frontend, or `(INFRA)` infrastructure. Each phase builds on the previous — do not skip phases.

---

### Phase 0: Infrastructure Setup

#### Docker and Nginx

- [ ] **5.2.1** (INFRA) Create `docker/backend/Dockerfile` — Python 3.11-slim base, install system deps including WeasyPrint dependencies (libpango, libcairo, libgdk-pixbuf), pip install requirements, expose 8000, CMD daphne
- [ ] **5.2.2** (INFRA) Create `docker/backend/entrypoint.sh` — wait for PostgreSQL readiness, run migrate, collectstatic, then execute CMD
- [ ] **5.2.3** (INFRA) Create `docker/frontend/Dockerfile` — Node 20-alpine base, multi-stage: dev target uses Vite dev server, prod target builds with Vite and serves via Nginx
- [ ] **5.2.4** (INFRA) Create `docker/nginx/nginx.conf` — proxy `/api/`, `/admin/`, `/ws/` to backend (with WebSocket upgrade headers for `/ws/`); serve `/media/` from volume; proxy `/*` to frontend
- [ ] **5.2.5** (INFRA) Create `docker/nginx/Dockerfile` — FROM nginx:alpine, copy config
- [ ] **5.2.6** (INFRA) Create `docker-compose.yml` with all 8 services, named networks, and named volumes (`postgres_data`, `media_data`)
- [ ] **5.2.7** (INFRA) Create `docker-compose.override.yml` for dev — mount backend source for hot reload, mount frontend src for HMR, set DEBUG=1
- [ ] **5.2.8** (INFRA) Create `.env.example` with all required env vars: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `DATABASE_URL`, `REDIS_URL`, `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `CELERY_BROKER_URL`, `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `FRONTEND_URL`
- [ ] **5.2.9** (INFRA) Create `Makefile` with targets: `up`, `down`, `build`, `test-be`, `test-fe`, `migrate`, `shell`, `logs`, `seed`
- [ ] **5.2.10** (INFRA) Verify `docker-compose up` starts all 8 services without errors

#### GitHub Actions CI

- [ ] **6.2.1** (INFRA) Create `.github/workflows/ci.yml` — triggers on push to `master`/`develop` and PRs to `master`; runs 5 parallel jobs
- [ ] **6.2.2** (INFRA) Implement `backend-lint` job — setup Python 3.11, install Ruff, run `ruff check backend/` and `ruff format --check backend/`
- [ ] **6.2.3** (INFRA) Implement `backend-test` job — spin up postgres:15 and redis:7 services with health checks, install requirements, run pytest with coverage, upload coverage artifact
- [ ] **6.2.4** (INFRA) Implement `frontend-lint` job — setup Node 20, cache node_modules, `npm ci`, run ESLint and `tsc --noEmit`
- [ ] **6.2.5** (INFRA) Implement `frontend-test` job — setup Node 20, `npm ci`, run Vitest with coverage
- [ ] **6.2.6** (INFRA) Implement `frontend-build` job — setup Node 20, `npm ci`, run Vite production build
- [ ] **6.2.7** (INFRA) Create `backend/pytest.ini` (or `pyproject.toml` pytest section) — set `DJANGO_SETTINGS_MODULE=config.settings.test`, `python_files=test_*.py`, verbosity flags
- [ ] **6.2.8** (INFRA) Create `backend/conftest.py` placeholder — shared fixtures will be filled in Phase 7
- [ ] **6.2.9** (BE) Create `config/settings/test.py` — inherit from base, use in-memory file storage, console email backend, `CELERY_TASK_ALWAYS_EAGER=True`, disabled throttling, MD5 password hasher

---

### Phase 1: Core Foundation

#### 1.1 `core` App — Shared Utilities

- [ ] **1.1.1** (BE) Create the `core` app package with `__init__.py`
- [ ] **1.1.2** (BE) Implement `TimeStampedModel` abstract base model with `created_at` and `updated_at` auto-populated fields
- [ ] **1.1.3** (BE) Implement `UUIDModel` abstract base model with UUID v4 primary key, combined with `TimeStampedModel` into a single `BaseModel`
- [ ] **1.1.4** (BE) Implement `IsOwnerPermission` DRF permission class — request-level check that `user.role == OWNER`
- [ ] **1.1.5** (BE) Implement `IsTenantPermission` DRF permission class — request-level check that `user.role == TENANT`
- [ ] **1.1.6** (BE) Implement `IsObjectOwnerPermission` DRF object-level permission — checks `obj.owner == request.user`
- [ ] **1.1.7** (BE) Implement `IsBookingParticipantPermission` DRF object-level permission — user is either the booking's tenant or the booking's equipment owner
- [ ] **1.1.8** (BE) Implement `StandardResultsSetPagination` — default page size 20, max 100
- [ ] **1.1.9** (BE) Implement custom DRF exception handler — returns consistent JSON: `{"error": {"code": ..., "message": ..., "details": ...}}`
- [ ] **1.1.10** (BE) Define shared enums module: `UserRole`, `BookingStatus`, `PaymentStatus`, `EquipmentCategory`

---

### Phase 2: Auth and RBAC

#### 1.2 `accounts` App — Backend

- [ ] **1.2.1** (BE) Create the `accounts` app with standard Django structure
- [ ] **1.2.2** (BE) Implement custom `User` model extending `AbstractUser` — UUID pk, email as unique login identifier, first_name, last_name, phone, role (TENANT/OWNER enum), is_email_verified bool, timestamps from BaseModel
- [ ] **1.2.3** (BE) Implement custom `UserManager` with `create_user` and `create_superuser` using email as the identifier field instead of username
- [ ] **1.2.4** (BE) Implement `EmailVerificationToken` model — UUID pk, user FK, token string (unique), expires_at datetime, is_used bool
- [ ] **1.2.5** (BE) Create and run initial migrations for accounts app
- [ ] **1.2.6** (BE) Configure SimpleJWT in settings — access token 30 min, refresh token 7 days, rotate refresh tokens enabled
- [ ] **1.2.7** (BE) Implement registration serializer — validates email, password, password_confirm, first_name, last_name, role; rejects mismatched passwords and duplicate emails
- [ ] **1.2.8** (BE) Implement registration view (POST `/auth/register/`) — creates user, dispatches `send_verification_email` Celery task
- [ ] **1.2.9** (BE) Implement login view (POST `/auth/login/`) — extend SimpleJWT `TokenObtainPairView`
- [ ] **1.2.10** (BE) Implement token refresh view (POST `/auth/token/refresh/`)
- [ ] **1.2.11** (BE) Implement email verification view (POST `/auth/verify-email/`) — validates token, checks expiry and is_used, marks user as verified
- [ ] **1.2.12** (BE) Implement user profile view (GET/PATCH `/auth/me/`) — returns and updates profile fields; explicitly rejects any attempt to change role
- [ ] **1.2.13** (BE) Wire `post_save` signal on User to dispatch `send_verification_email` Celery task on creation
- [ ] **1.2.14** (BE) Register User and EmailVerificationToken in Django admin

#### Auth Frontend

- [ ] **4.3.1** (FE) Create React project with Vite + TypeScript template inside `frontend/`
- [ ] **4.3.2** (FE) Install and configure Tailwind CSS
- [ ] **4.3.3** (FE) Install and configure React Router v6 with all route definitions
- [ ] **4.3.4** (FE) Install and configure Redux Toolkit and RTK Query
- [ ] **4.3.5** (FE) Create base RTK Query API client (`frontend/src/app/api.ts`) with JWT auth header injection via `prepareHeaders`
- [ ] **4.3.6** (FE) Create `authSlice` — stores JWT tokens and user info in Redux state, persisted to localStorage; login and logout reducers
- [ ] **4.3.7** (FE) Build `Navbar` component — logo, nav links, conditional rendering based on auth state (login/register buttons or user dropdown with logout)
- [ ] **4.3.8** (FE) Build `ProtectedRoute` component — wraps routes that require auth; redirects to `/login` if no token
- [ ] **4.3.9** (FE) Build `RoleGuard` component — renders children only if the authenticated user has the required role
- [ ] **4.3.10** (FE) Build `LoginPage` — email field, password field, submit button, API error display
- [ ] **4.3.11** (FE) Build `RegisterPage` — email, password, confirm password, first name, last name, role radio (TENANT/OWNER), form validation
- [ ] **4.3.12** (FE) Build `VerifyEmailPage` — reads token from URL params, calls verify endpoint on mount, renders success or error state
- [ ] **4.5.1** (FE) Create `features/auth/api.ts` — RTK Query endpoints: register, login, refreshToken, verifyEmail, getMe, updateMe

---

### Phase 3: Equipment — Search, Filter, Detail, Gallery

#### 1.3 `equipment` App — Backend

- [ ] **1.3.1** (BE) Create the `equipment` app
- [ ] **1.3.2** (BE) Implement `Equipment` model — UUID pk, owner FK->User, title string, description text, category enum, daily_rate decimal, location string, is_available bool, timestamps
- [ ] **1.3.3** (BE) Implement `EquipmentPhoto` model — UUID pk, equipment FK, image FileField, sort_order int, is_primary bool
- [ ] **1.3.4** (BE) Create and run migrations for equipment app
- [ ] **1.3.5** (BE) Implement public equipment list viewset with django-filter backend — filters: category, location, min_price, max_price, full-text search on title + description, available_from/available_to (excludes equipment with overlapping confirmed/paid bookings)
- [ ] **1.3.6** (BE) Implement public equipment detail view — returns equipment with nested photos serializer
- [ ] **1.3.7** (BE) Implement occupancy calendar endpoint (GET `/equipment/{id}/calendar/`) — returns array of booked date range objects from confirmed and paid bookings
- [ ] **1.3.8** (BE) Implement owner-only equipment CRUD viewset — create auto-sets `owner=request.user`; update and delete enforce `IsObjectOwnerPermission`
- [ ] **1.3.9** (BE) Implement photo upload endpoint (POST `/equipment/{id}/photos/`) — accepts multipart with multiple files, creates EquipmentPhoto rows
- [ ] **1.3.10** (BE) Implement photo delete endpoint (DELETE `/equipment/{id}/photos/{photo_id}/`)
- [ ] **1.3.11** (BE) Implement photo reorder endpoint (PATCH `/equipment/{id}/photos/reorder/`) — accepts ordered list of photo IDs, updates sort_order accordingly
- [ ] **1.3.14** (BE) Register Equipment and EquipmentPhoto in Django admin

#### Equipment Frontend

- [ ] **4.3.13** (FE) Build `HomePage` — hero section with headline, `SearchBar` component, featured equipment card preview row
- [ ] **4.3.14** (FE) Build `SearchBar` component — text input with 300ms debounce using `useDeferredValue` or a custom debounce hook
- [ ] **4.3.15** (FE) Build `FilterSidebar` component — category checkboxes, min/max price inputs, available date range picker; state stored in URL search params
- [ ] **4.3.16** (FE) Build `EquipmentListPage` — renders `SearchBar`, `FilterSidebar`, equipment card grid, and `Pagination`
- [ ] **4.3.17** (FE) Build `PhotoGallery` component — lightbox-style main image with thumbnail strip, keyboard navigation
- [ ] **4.3.18** (FE) Build `OccupancyCalendar` component — month calendar view highlighting booked date ranges as unavailable
- [ ] **4.3.19** (FE) Build `EquipmentDetailPage` — `PhotoGallery`, description, daily rate display, `OccupancyCalendar`, booking date picker with "Book Now" submit action
- [ ] **4.3.33** (FE) Build shared `Pagination` component — renders page numbers, calls `onPageChange` callback
- [ ] **4.3.34** (FE) Build shared `EmptyState` component — placeholder UI for empty lists
- [ ] **4.3.35** (FE) Build shared `LoadingSpinner` component
- [ ] **4.5.2** (FE) Create `features/equipment/api.ts` — RTK Query endpoints: listEquipment, getEquipment, getCalendar, createEquipment, updateEquipment, deleteEquipment, uploadPhotos, deletePhoto, reorderPhotos

---

### Phase 4: Bookings — Lifecycle, Redis Draft, Calendar

#### 1.4 `bookings` App — Backend

- [ ] **1.4.1** (BE) Create the `bookings` app
- [ ] **1.4.2** (BE) Implement `Booking` model — UUID pk, equipment FK, tenant FK->User, start_date, end_date, total_price decimal, status enum, rejection_reason text nullable, timestamps
- [ ] **1.4.3** (BE) Create and run migrations for bookings app
- [ ] **1.4.4** (BE) Implement `DraftBookingService` — Redis SET with key `draft:{equipment_id}:{user_id}` and 15-min TTL; methods: `create_draft`, `get_draft`, `delete_draft`, `is_locked`
- [ ] **1.4.5** (BE) Implement draft booking endpoint (POST `/bookings/draft/`) — checks date availability, creates Redis lock, returns draft metadata
- [ ] **1.4.6** (BE) Implement booking creation endpoint (POST `/bookings/`) — validates draft exists and has not expired, creates Booking row as PENDING, deletes Redis draft
- [ ] **1.4.7** (BE) Implement booking list endpoint (GET `/bookings/`) — tenant sees own bookings; owner sees bookings for their equipment; optional status query param filter
- [ ] **1.4.8** (BE) Implement booking detail endpoint (GET `/bookings/{id}/`) — restricted to participants via `IsBookingParticipantPermission`
- [ ] **1.4.9** (BE) Implement booking action endpoints as separate views: `confirm/` (Owner, PENDING -> CONFIRMED), `reject/` (Owner, PENDING -> REJECTED, requires rejection_reason), `cancel/` (Tenant, PENDING or CONFIRMED -> CANCELLED), `complete/` (Owner, PAID -> COMPLETED)
- [ ] **1.4.10** (BE) Implement status transition validation — a view attempting an invalid transition returns 400 with a descriptive message
- [ ] **1.4.11** (BE) Implement date overlap validation on booking creation — query for any non-cancelled booking on the same equipment with overlapping date range; return 400 if found
- [ ] **1.4.12** (BE) Wire booking status change to dispatch `send_booking_notification` Celery task
- [ ] **1.4.13** (BE) Implement dashboard bookings endpoint (GET `/dashboard/bookings/`) — owner's incoming booking requests with optional status filter
- [ ] **1.4.14** (BE) Register Booking in Django admin

#### Bookings Frontend

- [ ] **4.3.20** (FE) Build `StatusBadge` component — maps each BookingStatus and PaymentStatus value to a colored badge label
- [ ] **4.3.21** (FE) Build `BookingsListPage` — list of booking cards with filter tabs: All / Pending / Confirmed / Paid / Completed
- [ ] **4.3.22** (FE) Build `BookingDetailPage` layout — booking summary header, role-based action buttons, payment section, chat section below
- [ ] **4.3.36** (FE) Build shared `ConfirmDialog` modal — generic confirmation dialog with configurable message and confirm/cancel actions
- [ ] **4.5.3** (FE) Create `features/bookings/api.ts` — RTK Query endpoints: createDraft, createBooking, listBookings, getBooking, confirmBooking, rejectBooking, cancelBooking, completeBooking

---

### Phase 5: Owner Dashboard — CRUD, Stats, Charts

#### Dashboard Endpoints (additional views inside `equipment` and `bookings` apps)

- [ ] **1.3.12** (BE) Implement dashboard stats endpoint (GET `/dashboard/stats/`) — aggregates: total income from PAID/COMPLETED bookings, count of active listings, count of idle equipment (is_available with no active booking), booking counts grouped by status
- [ ] **1.3.13** (BE) Implement dashboard equipment list endpoint (GET `/dashboard/equipment/`) — owner's equipment rows, each annotated with booking count summary

#### Dashboard Frontend

- [ ] **4.3.28** (FE) Build `DashboardPage` layout — stats cards row at top, owner's equipment table in middle, incoming booking requests list at bottom
- [ ] **4.3.29** (FE) Build `StatsChart` components — income over time as a line chart, idle days as a bar chart using Recharts
- [ ] **4.3.30** (FE) Build `DragDropUpload` component — drag-and-drop zone accepting multiple files, shows preview thumbnails, supports reordering via drag
- [ ] **4.3.31** (FE) Build `EquipmentFormPage` — controlled form for creating and editing equipment: title, description, category select, daily rate, location, photo upload via `DragDropUpload`
- [ ] **4.3.32** (FE) Build booking management section in `DashboardPage` — table of incoming PENDING requests with approve and reject action buttons per row
- [ ] **4.5.6** (FE) Create `features/dashboard/api.ts` — RTK Query endpoints: getStats, getDashboardEquipment, getDashboardBookings

---

### Phase 6: Real-time Chat — WebSockets, Typing, Read Receipts

#### 1.5 `chat` App — Backend

- [ ] **1.5.1** (BE) Create the `chat` app
- [ ] **1.5.2** (BE) Install and configure Django Channels with Redis channel layer (`CHANNEL_LAYERS` setting pointing to Redis)
- [ ] **1.5.3** (BE) Configure ASGI application in `config/asgi.py` — `URLRouter` that routes HTTP to Django and WebSocket paths to Channels consumers
- [ ] **1.5.4** (BE) Implement `ChatRoom` model — UUID pk, booking FK (one-to-one), created_at
- [ ] **1.5.5** (BE) Implement `Message` model — UUID pk, room FK, sender FK->User, content text, is_read bool (default False), created_at
- [ ] **1.5.6** (BE) Create and run migrations for chat app
- [ ] **1.5.7** (BE) Implement `ChatConsumer` WebSocket consumer — `connect`: authenticate JWT from query string, verify user is a booking participant, join channel group; `disconnect`: leave group; `receive`: dispatch by `type` field
- [ ] **1.5.8** (BE) Implement `chat.message` handler in consumer — persist Message to DB, broadcast `new_message` event to the room's channel group
- [ ] **1.5.9** (BE) Implement `chat.typing` handler in consumer — broadcast `typing` event to group, no DB write
- [ ] **1.5.10** (BE) Implement `chat.read` handler in consumer — bulk-update specified message IDs to `is_read=True`, broadcast `read_receipt` event
- [ ] **1.5.11** (BE) Implement Channels URL routing — register `ws/chat/{booking_id}/` path to `ChatConsumer`
- [ ] **1.5.12** (BE) Implement message history REST endpoint (GET `/chat/rooms/{id}/messages/`) — paginated response, ordered newest first
- [ ] **1.5.13** (BE) Implement chat room list REST endpoint (GET `/chat/rooms/`) — returns rooms where the requesting user is tenant or equipment owner
- [ ] **1.5.14** (BE) Auto-create `ChatRoom` record when a booking transitions to CONFIRMED status — add this to the confirm action view or booking post-save signal
- [ ] **1.5.15** (BE) Register ChatRoom and Message in Django admin

#### Chat Frontend

- [ ] **4.3.24** (FE) Build `ChatWindow` component — renders message list, text input, send button; manages WebSocket lifecycle with `useRef` and `useEffect`
- [ ] **4.3.25** (FE) Implement typing indicator in `ChatWindow` — send `chat.typing` event on input change with debounce; display "User is typing..." when received
- [ ] **4.3.26** (FE) Implement read receipts in `ChatWindow` — send `chat.read` event when messages scroll into view; display checkmarks on sent messages based on is_read
- [ ] **4.3.27** (FE) Integrate `ChatWindow` into `BookingDetailPage` — render only when a ChatRoom exists for the booking (CONFIRMED or later status)
- [ ] **4.5.4** (FE) Create `features/chat/api.ts` — RTK Query endpoints: listRooms, getMessages

---

### Phase 7: Documents and Payments — PDF Invoice, Stripe Mock

#### 1.6 `payments` App — Backend

- [ ] **1.6.1** (BE) Create the `payments` app
- [ ] **1.6.2** (BE) Implement `Payment` model — UUID pk, booking FK (one-to-one), amount decimal, stripe_payment_intent_id string, status enum (PENDING/SUCCEEDED/FAILED), paid_at nullable datetime, timestamps
- [ ] **1.6.3** (BE) Implement `Invoice` model — UUID pk, payment FK (one-to-one), pdf_file FileField, generated_at datetime
- [ ] **1.6.4** (BE) Create and run migrations for payments app
- [ ] **1.6.5** (BE) Implement `StripeMockService` class using Strategy pattern — `create_payment_intent(amount)` returns dict with fake `id`, `client_secret`, and `status`; `confirm_payment(intent_id)` returns `{"status": "succeeded"}`
- [ ] **1.6.6** (BE) Implement payment creation endpoint (POST `/payments/`) — restricted to CONFIRMED bookings; creates Payment row and calls `StripeMockService.create_payment_intent`
- [ ] **1.6.7** (BE) Implement payment confirmation endpoint (POST `/payments/{id}/confirm/`) — calls mock confirm, updates Payment status to SUCCEEDED, transitions Booking to PAID
- [ ] **1.6.8** (BE) Implement payment detail endpoint (GET `/payments/{id}/`) — accessible by booking participants only
- [ ] **1.6.9** (BE) Implement HTML invoice template for WeasyPrint — shows booking dates, equipment title, tenant name, amount, generated date, and a company header
- [ ] **1.6.10** (BE) Implement `generate_invoice` Celery task — renders invoice HTML template to PDF bytes via WeasyPrint, saves to `Invoice.pdf_file` FileField
- [ ] **1.6.11** (BE) Wire payment confirmation view to dispatch `generate_invoice` and `send_payment_confirmation` tasks after status update
- [ ] **1.6.12** (BE) Implement invoice download endpoint (GET `/payments/{id}/invoice/`) — returns `FileResponse` with `Content-Type: application/pdf`; returns 404 if Invoice record has no file yet
- [ ] **1.6.13** (BE) Register Payment and Invoice in Django admin

#### 1.7 `notifications` App — Backend

- [ ] **1.7.1** (BE) Create the `notifications` app
- [ ] **1.7.2** (BE) Implement `send_verification_email` Celery task — accepts `user_id`, fetches user, renders verification email HTML with token link, calls `send_mail`
- [ ] **1.7.3** (BE) Implement `send_booking_notification` Celery task — accepts `booking_id` and new `status`; sends appropriate email to the relevant party (owner on new PENDING, tenant on CONFIRMED/REJECTED/CANCELLED)
- [ ] **1.7.4** (BE) Implement `send_payment_confirmation` Celery task — accepts `payment_id`, sends receipt email with invoice details to tenant
- [ ] **1.7.5** (BE) Create email templates directory (`backend/templates/emails/`) with HTML templates: `verification.html`, `booking_notification.html`, `payment_confirmation.html`
- [ ] **1.7.6** (BE) Configure Django email backend — `console.EmailBackend` for dev, SMTP via env vars for prod

#### Test Factories and Fixtures (finalize `conftest.py`)

- [ ] **7.3.1** (BE) Implement `UserFactory` using factory-boy — role configurable, defaults to TENANT
- [ ] **7.3.2** (BE) Implement `EquipmentFactory` — auto-creates an Owner User as the equipment owner
- [ ] **7.3.3** (BE) Implement `EquipmentPhotoFactory` — creates a photo record linked to an Equipment
- [ ] **7.3.4** (BE) Implement `BookingFactory` — auto-creates Equipment and a Tenant User
- [ ] **7.3.5** (BE) Implement `ChatRoomFactory` — auto-creates a Booking
- [ ] **7.3.6** (BE) Implement `MessageFactory` — creates a Message linked to a ChatRoom
- [ ] **7.3.7** (BE) Implement `PaymentFactory` — creates a Payment for a Booking
- [ ] **7.3.8** (BE) Implement `InvoiceFactory` — creates an Invoice for a Payment
- [ ] **7.3.9** (BE) Implement pytest fixtures in `conftest.py`: `api_client`, `tenant_user`, `owner_user`, `authenticated_client` (parameterized by user), `sample_equipment`, `sample_booking`

#### Payments Frontend

- [ ] **4.3.23** (FE) Build payment flow in `BookingDetailPage` — Pay button triggers `createPayment`, confirm dialog triggers `confirmPayment`, on success displays invoice download link
- [ ] **4.5.5** (FE) Create `features/payments/api.ts` — RTK Query endpoints: createPayment, confirmPayment, getPayment, downloadInvoice

---

## API Reference

All endpoints are prefixed with `/api/v1/`.

### Auth — `/api/v1/auth/`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register/` | Public | Register new user with role selection |
| POST | `/auth/login/` | Public | Obtain JWT access + refresh token pair |
| POST | `/auth/token/refresh/` | Public | Exchange refresh token for new access token |
| POST | `/auth/verify-email/` | Public | Verify email address using token from email link |
| GET | `/auth/me/` | Required | Get authenticated user's profile |
| PATCH | `/auth/me/` | Required | Update profile fields; role changes are rejected |

### Equipment — `/api/v1/equipment/`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/equipment/` | Public | List equipment with optional search and filters |
| GET | `/equipment/{id}/` | Public | Equipment detail with nested photos array |
| GET | `/equipment/{id}/calendar/` | Public | Booked date ranges for occupancy calendar display |
| POST | `/equipment/` | Owner | Create a new equipment listing |
| PATCH | `/equipment/{id}/` | Owner of item | Update equipment listing fields |
| DELETE | `/equipment/{id}/` | Owner of item | Delete equipment listing |
| POST | `/equipment/{id}/photos/` | Owner of item | Upload one or more photos (multipart) |
| DELETE | `/equipment/{id}/photos/{photo_id}/` | Owner of item | Delete a specific photo |
| PATCH | `/equipment/{id}/photos/reorder/` | Owner of item | Reorder photos via ordered list of IDs |

Search query parameters: `?category=`, `?location=`, `?min_price=`, `?max_price=`, `?available_from=`, `?available_to=`, `?search=`

### Bookings — `/api/v1/bookings/`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/bookings/draft/` | Tenant | Create a 15-min Redis draft lock for a date range |
| POST | `/bookings/` | Tenant | Convert a valid draft into a PENDING booking |
| GET | `/bookings/` | Any | List own bookings; scope is determined by role |
| GET | `/bookings/{id}/` | Participant | Booking detail |
| POST | `/bookings/{id}/confirm/` | Owner of equipment | Transition PENDING to CONFIRMED |
| POST | `/bookings/{id}/reject/` | Owner of equipment | Transition PENDING to REJECTED (reason required) |
| POST | `/bookings/{id}/complete/` | Owner of equipment | Transition PAID to COMPLETED |
| POST | `/bookings/{id}/cancel/` | Tenant | Cancel from PENDING or CONFIRMED state |

### Chat — `/api/v1/chat/` and WebSocket

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/chat/rooms/` | Any | List chat rooms where user is a participant |
| GET | `/chat/rooms/{id}/messages/` | Participant | Paginated message history, newest first |
| WebSocket | `ws/chat/{booking_id}/` | JWT query param | Real-time bidirectional chat connection |

WebSocket message types:

| Direction | Type | Persisted | Description |
|---|---|---|---|
| Client -> Server | `chat.message` | Yes | Send a new chat message |
| Client -> Server | `chat.typing` | No | Broadcast typing indicator to room |
| Client -> Server | `chat.read` | Yes | Mark specified message IDs as read |
| Server -> Client | `new_message` | — | New message broadcast to all room members |
| Server -> Client | `typing` | — | Typing indicator broadcast |
| Server -> Client | `read_receipt` | — | Read receipt broadcast after is_read update |

### Payments — `/api/v1/payments/`

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/payments/` | Tenant (Participant) | Create mock payment intent for a CONFIRMED booking |
| POST | `/payments/{id}/confirm/` | Tenant (Participant) | Confirm payment; transitions booking to PAID |
| GET | `/payments/{id}/` | Participant | Payment detail |
| GET | `/payments/{id}/invoice/` | Participant | Download invoice as PDF file |

### Owner Dashboard — `/api/v1/dashboard/`

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/dashboard/stats/` | Owner | Total income, active listing count, idle count, booking counts by status |
| GET | `/dashboard/bookings/` | Owner | Incoming booking requests with optional status filter |
| GET | `/dashboard/equipment/` | Owner | Owner's equipment list with per-item booking summary |

---

## Test Architecture

This section is the TDD reference guide for the project. Each bullet defines a specific test case to implement. Tests are organized by app and test layer. The CI gate requires 80% backend coverage and 100% passing frontend tests before merge.

**Testing stack:**
- Backend: `pytest`, `pytest-django`, `pytest-asyncio`, `factory-boy`, `channels[tests]`, `pytest-cov`
- Frontend: `vitest`, `@testing-library/react`, `@testing-library/user-event`, `msw` (Mock Service Worker)

**Backend test directory layout:**

```
backend/
  conftest.py                        # Shared factories and fixtures
  apps/
    accounts/tests/
      test_models.py                 # User, EmailVerificationToken models
      test_serializers.py            # Registration serializer validation
      test_views.py                  # All auth endpoints
    equipment/tests/
      test_models.py                 # Equipment, EquipmentPhoto models
      test_views.py                  # CRUD and search/filter endpoints
      test_filters.py                # Date-range availability filter logic
    bookings/tests/
      test_models.py                 # Booking model, status transitions
      test_views.py                  # All booking endpoints
      test_services.py               # DraftBookingService (Redis)
    chat/tests/
      test_models.py                 # ChatRoom, Message models
      test_consumers.py              # WebSocket consumer tests
      test_views.py                  # Message history, room list
    payments/tests/
      test_models.py                 # Payment, Invoice models
      test_views.py                  # Payment and invoice endpoints
      test_services.py               # StripeMockService
      test_tasks.py                  # generate_invoice Celery task
    notifications/tests/
      test_tasks.py                  # All email Celery tasks
```

---

### Unit Tests

#### `accounts` — `test_models.py` and `test_serializers.py`

- User created with TENANT role stores `role=TENANT` correctly
- User created with OWNER role stores `role=OWNER` correctly
- Creating a second User with the same email raises an IntegrityError
- A newly created User has `is_email_verified=False` by default
- Registration serializer with valid data passes validation and returns cleaned data
- Registration serializer with a missing required field raises a field-level ValidationError
- Registration serializer with a duplicate email raises a ValidationError on the email field
- Registration serializer with mismatched `password` and `password_confirm` raises a ValidationError
- Registration serializer with an invalid role string raises a ValidationError
- `EmailVerificationToken` token field is unique across records
- `EmailVerificationToken` correctly identifies an expired token based on `expires_at`

#### `equipment` — `test_models.py`

- `Equipment.__str__` returns a meaningful string representation
- `Equipment.daily_rate` field rejects negative decimal values
- `EquipmentPhoto` queryset ordered by `sort_order` returns photos in ascending order
- `EquipmentPhoto.is_primary` constraint behavior (define expected behavior and test it)

#### `bookings` — `test_models.py` and `test_services.py`

- `Booking.total_price` equals `daily_rate * number_of_days` when calculated at creation
- Applying a valid status transition does not raise
- Applying an invalid status transition raises the appropriate exception
- `DraftBookingService.create_draft` writes a Redis key in the format `draft:{equipment_id}:{user_id}`
- `DraftBookingService.create_draft` sets a TTL of exactly 15 minutes on the Redis key
- `DraftBookingService.is_locked` returns `True` when the key exists
- `DraftBookingService.is_locked` returns `False` after the key has expired (simulate with immediate TTL)

#### `chat` — `test_models.py`

- `Message.is_read` defaults to `False` on creation
- A queryset of Messages ordered by `created_at` returns them in ascending chronological order
- `ChatRoom` enforces a one-to-one relationship with `Booking` at the database level

#### `payments` — `test_models.py` and `test_services.py`

- Transitioning a Payment from PENDING to SUCCEEDED is accepted
- Transitioning a Payment from PENDING to FAILED is accepted
- `StripeMockService.create_payment_intent` returns a dict containing `id`, `client_secret`, and `status` keys
- `StripeMockService.confirm_payment` returns a dict with `status` equal to `"succeeded"`
- `Invoice.generated_at` is set to a non-null datetime when the record is created

---

### Integration Tests

#### `accounts` — `test_views.py`

- `POST /auth/register/` returns 201, a User row exists in the DB, and the email task was called (mock Celery with `CELERY_TASK_ALWAYS_EAGER=True`)
- `POST /auth/login/` returns 200 with `access` and `refresh` tokens for valid credentials
- `POST /auth/login/` returns 401 for a wrong password
- `POST /auth/login/` returns 401 for unverified email (if enforcement is configured)
- `POST /auth/token/refresh/` returns 200 with a new `access` token for a valid refresh token
- `POST /auth/token/refresh/` returns 401 for an expired refresh token
- `POST /auth/verify-email/` returns 200 and sets `is_email_verified=True` for a valid, unexpired token
- `POST /auth/verify-email/` returns 400 for an expired token
- `POST /auth/verify-email/` returns 400 for a token that has already been used
- `GET /auth/me/` returns 200 with profile data for an authenticated user
- `GET /auth/me/` returns 401 for an unauthenticated request (no token)
- `PATCH /auth/me/` with valid fields returns 200 and updates the record
- `PATCH /auth/me/` with a `role` field does not change the user's role
- An Owner-only endpoint called by a Tenant returns 403
- A Tenant-only endpoint called by an Owner returns 403

#### `equipment` — `test_views.py` and `test_filters.py`

- `GET /equipment/` returns a paginated response structure with `results` array
- `GET /equipment/?search=crane` returns only equipment whose title or description contains "crane"
- `GET /equipment/?category=EXCAVATOR` returns only EXCAVATOR-category items
- `GET /equipment/?min_price=100&max_price=500` returns only items with `daily_rate` in that range
- `GET /equipment/?available_from=X&available_to=Y` excludes equipment that has a non-cancelled booking overlapping those dates
- `GET /equipment/{id}/` returns equipment detail with a nested `photos` array
- `GET /equipment/{id}/calendar/` returns an array of objects with `start_date` and `end_date` keys
- `POST /equipment/` as an Owner returns 201 and the created record has `owner` equal to the requesting user
- `POST /equipment/` as a Tenant returns 403
- `PATCH /equipment/{id}/` by the item's owner returns 200 with updated data
- `PATCH /equipment/{id}/` by a different Owner user returns 403
- `DELETE /equipment/{id}/` by the item's owner returns 204 and the record is gone
- `POST /equipment/{id}/photos/` with two files creates two `EquipmentPhoto` rows
- `DELETE /equipment/{id}/photos/{photo_id}/` returns 204 and removes the photo record

#### `bookings` — `test_views.py`

- `POST /bookings/draft/` creates a Redis key and returns draft metadata
- `POST /bookings/draft/` returns 409 when the equipment is already locked by another user's draft
- `POST /bookings/` with a valid draft creates a PENDING Booking row and removes the Redis key
- `POST /bookings/` returns 400 when the draft has already expired
- `POST /bookings/` returns 400 when requested dates overlap with an existing non-cancelled booking
- `POST /bookings/{id}/confirm/` as the equipment Owner transitions the booking to CONFIRMED
- `POST /bookings/{id}/confirm/` as the Tenant returns 403
- `POST /bookings/{id}/reject/` without `rejection_reason` in the request body returns 400
- `POST /bookings/{id}/cancel/` from PENDING status returns 200 and sets status to CANCELLED
- `POST /bookings/{id}/cancel/` from CONFIRMED status returns 200 and sets status to CANCELLED
- `POST /bookings/{id}/cancel/` from PAID status returns 400
- `POST /bookings/{id}/complete/` from PAID status returns 200 and sets status to COMPLETED
- `POST /bookings/{id}/complete/` from CONFIRMED status returns 400
- `GET /bookings/` as Tenant returns only bookings where the tenant is the requesting user
- `GET /bookings/` as Owner returns only bookings for equipment owned by the requesting user
- `GET /bookings/{id}/` by a user who is neither tenant nor equipment owner returns 403

#### `chat` — `test_views.py`

- `GET /chat/rooms/` returns only rooms where the requesting user is a participant (as tenant or owner)
- `GET /chat/rooms/{id}/messages/` returns a paginated list of messages for a room the user belongs to
- `GET /chat/rooms/{id}/messages/` returns 403 for a user who is not a room participant

#### `payments` — `test_views.py`

- `POST /payments/` creates a Payment record for a CONFIRMED booking
- `POST /payments/` returns 400 if the booking status is not CONFIRMED
- `POST /payments/{id}/confirm/` updates the Payment `status` to SUCCEEDED
- `POST /payments/{id}/confirm/` transitions the related Booking status to PAID
- `POST /payments/{id}/confirm/` triggers the `generate_invoice` task (assert it was called with `CELERY_TASK_ALWAYS_EAGER=True`)
- `GET /payments/{id}/` returns 200 for both the tenant and the equipment owner of the booking
- `GET /payments/{id}/invoice/` returns a response with `Content-Type: application/pdf`
- `GET /payments/{id}/invoice/` returns 404 when no Invoice record with a file exists yet
- `GET /payments/{id}/invoice/` returns 403 for a user who is not a booking participant

---

### E2E and WebSocket Tests

#### `chat` — `test_consumers.py` (using `channels.testing.WebsocketCommunicator`)

- An authenticated booking participant connects and does not receive an error or close frame
- A connection attempt with no JWT is rejected by the server (close frame received)
- A connection by a valid user who is not a participant in the booking is rejected
- After a participant sends a `chat.message` event, a `Message` row exists in the DB
- After a participant sends a `chat.message` event, all connected room members receive a `new_message` event
- After a participant sends a `chat.typing` event, connected room members receive a `typing` event and no DB row is created
- After a participant sends a `chat.read` event with message IDs, those Message rows have `is_read=True`
- After `chat.read`, all connected room members receive a `read_receipt` event
- A client that disconnects cleanly does not cause a server-side exception

---

### Celery Task Tests

#### `payments` — `test_tasks.py`

- `generate_invoice` called with a valid payment ID produces a non-empty file
- `generate_invoice` saves the generated PDF to the `Invoice.pdf_file` field, making it non-null
- The generated PDF content includes the booking's start date, end date, equipment title, and total price

#### `notifications` — `test_tasks.py`

- `send_verification_email` calls `send_mail` with the correct `to` address and a subject containing "verify" (case-insensitive)
- `send_booking_notification` called with status=CONFIRMED sends an email to the tenant's address
- `send_booking_notification` called with status=PENDING sends an email to the owner's address
- `send_booking_notification` called with status=REJECTED sends an email to the tenant's address
- `send_payment_confirmation` calls `send_mail` with the tenant's email as recipient and payment details in the body
- All three tasks handle a nonexistent user ID or deleted record without raising an unhandled exception

---

### CI Pipeline Test Jobs

| Job | Command | Pass Threshold |
|---|---|---|
| `backend-lint` | `ruff check backend/` and `ruff format --check backend/` | Zero violations |
| `backend-test` | `pytest --cov=apps --cov-report=xml --cov-fail-under=80` | 80% line coverage |
| `frontend-lint` | `eslint src/` and `tsc --noEmit` | Zero violations and zero type errors |
| `frontend-test` | `vitest run --coverage` | All tests pass |
| `frontend-build` | `vite build` | Build completes without error |

---

### Frontend Unit Tests (Vitest + React Testing Library)

- `LoginPage`: form validation fires on submit with empty fields; API error message renders when login fails
- `RegisterPage`: role radio buttons switch between TENANT and OWNER; form submits the selected role value
- `SearchBar`: user types a query and the onChange callback is invoked only after the 300ms debounce delay, not on every keystroke
- `FilterSidebar`: selecting a category checkbox propagates the updated filter value to the parent handler
- `PhotoGallery`: clicking a thumbnail updates the main image display; next and previous buttons cycle through images
- `OccupancyCalendar`: dates within a booked range render as disabled and are not selectable; dates outside booked ranges are selectable
- `StatusBadge`: renders the correct text label and CSS class for each value of `BookingStatus` and `PaymentStatus`
- `DragDropUpload`: a simulated file drop adds files to the preview list; files can be reordered via drag events
- `StatsChart`: renders without throwing errors when given a valid array of mock data points
- `ChatWindow`: renders existing messages from props; the text input accepts typed text; the send button calls the send handler
- `ChatWindow`: when `isTyping` is `true`, the typing indicator text is visible in the DOM
- `ProtectedRoute`: renders a redirect to `/login` when the Redux auth state contains no token
- `RoleGuard`: renders null for a user with the wrong role; renders children for a user with the required role
- `Pagination`: renders the expected number of page buttons based on `totalPages` prop; clicking a page button calls `onPageChange` with the correct page number

### Frontend Integration Tests (with MSW API Mocking)

- Auth flow: user fills registration form, MSW returns success, user fills login form, MSW returns tokens, Redux `authSlice` has token, user is redirected to home
- Equipment search: user types in the search bar, waits 300ms, MSW intercepts the GET request with the search param, matching equipment cards appear in the grid
- Booking flow: user selects start and end dates on `EquipmentDetailPage`, submits, MSW returns draft confirmation, user confirms, MSW returns PENDING booking, the booking card shows PENDING status
- Payment flow: user clicks Pay on `BookingDetailPage`, confirms in the dialog, MSW confirms the payment, booking status in the UI updates to PAID and an invoice download link appears
- RTK Query cache invalidation: after a booking is created via `createBooking` mutation, the `listBookings` query is invalidated and re-fetched, and the new booking appears in the list without a manual page reload

---

*Plan created: 2026-03-17 | Scope: Full architecture, implementation checklist, API reference, and test guide for HavyRentPro*
