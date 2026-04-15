# Deployment

## How it works

On every push to `main`, [`deploy.yml`](../.github/workflows/deploy.yml) runs:

1. Downloads Godot `4.6-stable` headless + web export templates
2. Imports the project (first-time resource import)
3. Exports the `Web` preset defined in [`export_presets.cfg`](../export_presets.cfg) to `exports/web/`
4. Injects [`coi-serviceworker`](https://github.com/gzuidhof/coi-serviceworker) into `index.html` so the game can use `SharedArrayBuffer` on GitHub Pages (which doesn't set COOP/COEP headers)
5. Writes `.nojekyll` so Pages serves underscore-prefixed files
6. Uploads the folder as a Pages artifact and deploys

## One-time repo setup

Before the first deploy works:

1. **Settings → Pages → Build and deployment → Source**: `GitHub Actions`
2. **Settings → Actions → General → Workflow permissions**: `Read and write permissions`

That's it — subsequent pushes to `main` auto-deploy.

## Local testing

To test the exported web build locally, you need COOP/COEP headers OR the service worker shim. The easiest way:

```bash
# From repo root, after exporting locally to exports/web
cd exports/web
python -m http.server 8000
# Open http://localhost:8000 — the coi-serviceworker will register and reload once
```

## Pinning Godot version

Bump `GODOT_VERSION` / `GODOT_STATUS` env vars in `deploy.yml`. The export preset feature list (`4.6`, `GL Compatibility`) in `project.godot` must match.
