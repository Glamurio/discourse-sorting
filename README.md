# discourse-sorting

Fixes for sorting problems on FluffyCommunity. Version 0.1.0, **not yet run on a live Discourse** (see "Status").

## What it does

### 1. `/top` with an explicit `order` (core bug, see meta topic 264831)

Core applies `order` / `ascending` before the `/top` list adds its own ranking, so the SQL becomes
`ORDER BY created_at DESC, <period score> DESC`. The period ranking is lost: on the live site
`/top.json?period=yearly&order=created` and `/top.json?period=all&order=created` return the same list.

With this plugin, when `order` is given explicitly, `/top` first picks the top N topics of the period by their
normal score (N = `discourse_sorting_top_candidates`, default 500, after category/tag/mute/permission filters),
then sorts that set by `order` and `ascending`. Requests without `order` go to core unchanged, so default
behaviour for everyone stays the same.

### 2. User Portfolio page sorting through the URL

`discourse-user-portfolio` is a **theme component**, not a plugin. Its route always sends the `portfolio_order`
theme setting and ignores the URL, so `/u/kami/activity/portfolio?order=created` did nothing. The server already
supports `order` and `ascending` on `/topics/created-by/:username`; this plugin only forwards them from the URL:

    /u/<name>/activity/portfolio?order=created                  newest first
    /u/<name>/activity/portfolio?order=created&ascending=true   oldest first

Allowed `order` values: created, activity, likes, op_likes, views, posts, posters, category.
The component's own tag and category settings still apply. Turn off with `discourse_sorting_portfolio_params`.
If the component is not installed, this part does nothing.

## Site settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `discourse_sorting_enabled` | true | Master switch |
| `discourse_sorting_top_candidates` | 500 | Size of the ranked set on `/top` when sorted explicitly |
| `discourse_sorting_portfolio_params` | true | URL sorting on the portfolio page |

## Install

Add to `containers/app.yml` under `hooks: after_code:` then rebuild:

    - git clone https://github.com/Glamurio/discourse-sorting.git

## Status

Checked: Ruby and YAML syntax, JS syntax, and the problem itself against the live site's JSON.
Not checked: nothing here has been loaded into a running Discourse, and `spec/` has not been run.
The portfolio part patches a theme component's route and controller from outside, which depends on
Ember's class lookup; verify it on a staging install first.

## Not included yet

- A visible sort control on the portfolio page (URL only for now).
- The booru-style layout; that belongs in a separate repo (theme component).
