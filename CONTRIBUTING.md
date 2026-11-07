# Contributing

Thanks for helping build our trip app! 🌴

## Workflow

1. Create a branch from `main`: `git switch -c feature/short-name`.
2. Make your change and run it locally (see [`web/README.md`](web/README.md)).
3. Run `npm run check` and `npm run build` in `web/`. Both must pass.
4. Open a pull request with a short description. Add screenshots for anything visual, at phone size (about 375 px wide).

## Guidelines

- **Mobile first.** Most of us use it on the phone, often on the street with a weak connection. Check 375 px width; nothing should scroll sideways.
- **Portuguese UI** (pt-BR) for everything people see, including error messages and `aria-label`s. English for code.
- **Keep the look:** the cozy island and travel theme, dark only. Use the tokens in `web/src/app.css` (`--sea`, `--sun`, `--leaf`, `--coral`…) and the icons in `Icon.svelte` instead of new colors or emoji in the UI.
- **Accessibility:** buttons at least 44 px, visible focus, and nothing communicated by color alone.
- **Database changes** go through Drizzle migrations (see `web/README.md`).

## Never commit secrets 🔒

- `.env` files are git-ignored. Keep it that way.
- No real API keys, passwords, tokens, server addresses or anyone's email address in code, tests, issues or PRs.
- If you leaked something by accident, tell Nelson right away. The key has to be rotated; deleting the commit isn't enough.
