# Salat Time — Web

Prayer times for every mosque, found from a spinning 3D globe; mosque pages with
news and comments; adhkar; the Qur'an; and a personal prayer tracker scored in
hasanat. The web sibling of the Salat Time Mac app (`mac_os/`, branch `main`).

**Status:** MVP in progress. Runs locally in Docker; not public yet.

```bash
cp .env.example .env               # then: docker compose exec app php artisan key:generate
docker compose up -d
npm install && npm run build
docker compose exec app php artisan migrate
docker compose exec app php artisan mosques:import
```

Open http://localhost:8095. See `AGENTS.md` for the stack, rules and commands.
