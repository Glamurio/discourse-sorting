# discourse-sorting

Sorting fixes and the server side of the optional booru view for FluffyCommunity. Version 0.2.0, **not yet run on a
live Discourse** (see "Status").

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

### 3. Tag counts within a search (for the booru sidebar)

`GET /discourse-sorting/tag-counts.json?q=<filter query>` returns how often each tag occurs among the topics a
`/filter` search with that query would list, highest first:

    { "tags": [{ "name": "foal", "count": 212 }, ...], "total_topics": 212, "truncated": false }

The topic set comes from the same code path as `/filter` itself (permissions, muted topics and every filter term
behave identically). Hidden tags are never returned. Limits: `discourse_sorting_tag_counts_limit` tags and
`discourse_sorting_tag_counts_max_topics` topics per request; `truncated` is true when a search had more topics
than that. Open to anonymous visitors, like `/filter`.

### 4. Per-account booru opt-in

`PUT /discourse-sorting/booru` with `enabled=true|false` (login required) stores the person's choice on their
account. It reaches the client as `currentUser.fluffy_booru`: `true` or `false` once chosen, `null` before. The
[`fluffybooru`](https://github.com/Glamurio/fluffybooru) theme component reads and writes it.

## Site settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `discourse_sorting_enabled` | true | Master switch |
| `discourse_sorting_top_candidates` | 500 | Size of the ranked set on `/top` when sorted explicitly |
| `discourse_sorting_portfolio_params` | true | URL sorting on the portfolio page |
| `discourse_sorting_tag_counts_limit` | 300 | Most tags returned by the tag counts endpoint |
| `discourse_sorting_tag_counts_max_topics` | 50000 | Most topics the tag counts endpoint examines per search |

## Install

Add to `containers/app.yml` under `hooks: after_code:` then rebuild:

    - git clone https://github.com/Glamurio/discourse-sorting.git

## Status

Checked: Ruby and YAML syntax, JS syntax, and the `/top` problem itself against the live site's JSON.
Not checked: nothing here has been loaded into a running Discourse, and `spec/` has not been run.

Things to verify on a staging install first:
- The portfolio part patches a theme component's route and controller from outside, which depends on Ember's
  class lookup.
- The tag counts endpoint reuses core's private `TopicQuery#filter_results` through a prepended method, and
  reads topic ids with `pluck`. Compare its numbers against what `/filter` lists for a few searches, and time it on
  the broadest searches (an empty query examines up to `discourse_sorting_tag_counts_max_topics` topics).
- That `currentUser.fluffy_booru` appears in `/session/current.json`.

## Load protection on the tag counts endpoint

Counting tags means scanning every topic a search matches, which is the most expensive thing this plugin does
(about 0.2 s for a normal tag search on the live site, over a second for an empty search). So:

- answers are cached for 5 minutes, separately per logged-in person (what they may see differs) and shared for
  guests, so the same search clicked again, or by many people, costs one scan;
- each logged-in person may make 60 requests a minute, and each guest address 30 (staff are exempt). Beyond that
  the endpoint answers 429; the booru sidebar then keeps showing the site-wide tag list.

## Not included yet

- A visible sort control on the portfolio page is part of the `fluffybooru` theme component, not this plugin.


## Tags reserved for groups

`GET /discourse-sorting/tag-counts/restricted.json` returns the names of tags in tag groups that the current person's groups may not use (the group's permissions list only other groups). `tag-counts` leaves them out too. Admins are never restricted.
