# DeHeus API

This is a Node.js Express API that connects to a local MySQL database.

## Setup

1. Navigate to the `api` directory:
   ```bash
   cd "dehus (Copy)/api"
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure environment variables:
   Check the `.env` file. It has been pre-configured with your local MySQL credentials:
   - `DB_HOST`: localhost
   - `DB_USER`: root
   - `DB_PASSWORD`: 3577
   - `DB_NAME`: longhorn

## Running the API

### Development mode (with auto-reload):
```bash
npm run dev
```

### Production mode:
```bash
npm start
```

## Endpoints

All endpoints support CRUD operations (GET, POST, PUT, DELETE):
- `/api/users`
- `/api/schools`
- `/api/tasks`
- `/api/geofences`
- `/api/route_plans`

## Hosting on Railway/Heroku

1. Link your repository.
2. Set the root directory to `dehus (Copy)/api` (or deploy only the `api` folder).
3. Add the environment variables (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`) in the hosting provider's dashboard.
