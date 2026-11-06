# Project docs

These docs are written for AI agents and humans working on Animal Scroller. They are the shared
memory of the project: several people work here, each with their own agents, and nobody else can
see your chat history. If it matters and it isn't in the code, it belongs here.

Rules for keeping them current are in [../AGENTS.md](../AGENTS.md#keeping-the-docs-current-required-for-every-change).

| Doc | What it holds | Update when |
| --- | --- | --- |
| [status.md](status.md) | What works, what's broken, who is working on what right now | Almost every PR |
| [changelog.md](changelog.md) | Every merged change, newest first | Every PR |
| [product.md](product.md) | Product requirements and how the app should behave | User-visible behaviour changes |
| [decisions.md](decisions.md) | Decision log: what was decided, by whom, and why | A real choice is made |
| [ai-content-audit.md](ai-content-audit.md) | AI-written material still in the repo and the plan to replace it | An item is fixed or found |
| [content-and-licensing.md](content-and-licensing.md) | Licence allowlist, attribution, paleoart and source rules | Content rules or sources change |
| [architecture.md](architecture.md) | Code map, data flow, extension points | Files or responsibilities change |
| [data-model.md](data-model.md) | Swift models, `taxonomy.json` shape, saved preferences | Any persisted or decoded shape changes |
| [design.md](design.md) | Zoo-board visual language: palette, fonts, card anatomy | Look and feel changes |
| [design/](design/README.md) | Concept screens from real photos, plus the layout rules behind them | Building or changing any screen |
| [roadmap.md](roadmap.md) | Phases and the next work items | Items finish, start or are dropped |
| [contributing.md](contributing.md) | Branches, PRs, tests, multi-agent etiquette | Process changes |

Other sources of truth:

- The concept deck (owner's slides): https://claude.ai/artifact/2AV6oC69cT5XeUxaphfNHU.
  It may not be viewable by everyone, so everything decided in it is copied into these docs.
- `README.md` at the repo root: short human quick start.
