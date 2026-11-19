# zenodo-openalex-collection

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24370578.svg)](https://doi.org/10.5281/zenodo.24370578)

Keeps an [OpenAlex collection](https://openalex.org) of the deposits in a
[Zenodo community](https://zenodo.org/communities) up to date, using a GitHub Action
that runs in **your** repository.

- All versions of all deposits in the community are downloaded from Zenodo.
- The OpenAlex collection is built from the **concept DOIs** (they always resolve to the
  newest version, and OpenAlex uses them as the main DOI of the merged work) or, for
  records without one (older records, records with a publisher DOI), the record's own
  DOI, searching all OpenAlex corpora (core + expansion — most Zenodo deposits are only in
  the expansion).
- Each run counts the community's records per interval (week, month, quarter, year or all) on
  Zenodo and downloads only the intervals that changed. The collection keeps its ID; members are added and removed.
- The README of your repository shows the last run, the numbers per collection, the last
  change on Zenodo (added / removed deposits) and the collection link.

This repository holds the code and the
[reusable workflow](.github/workflows/collection.yml). Your repository holds only a
`config.yml`, a short workflow and two secrets. Runs, API usage, data and collections
belong to your repository and accounts.

Example: [IPBES-Data/IPBES_OpenAlex_Collection](https://github.com/IPBES-Data/IPBES_OpenAlex_Collection).

## Setup

1. **Create a repository** (public or private) for your community.

2. **Add `config.yml`** — copy [`template/config.yml`](template/config.yml):

   ```yaml
   my-community:
     zenodo_community: my-community   # zenodo.org/communities/<this>
     collection_name: My Community Zenodo
     from: ~                          # optional date range, see below
     to: ~
     interval: year                   # week, month, quarter, year or all
     recheck:                         # optional, see "Data and runs"
       interval: month                # finer than interval
       per_run: 2                     # rolling: 2 months per run
     access: private                  # private, shared_by_link or public
   ```

   One entry per collection; the entry name is used for the folder `output/<name>/`.
   `collection_name` must be unique in your OpenAlex account.

3. **Add `.github/workflows/update.yml`** — copy [`template/update.yml`](template/update.yml):

   ```yaml
   name: Update collections
   on:
     schedule:
       - cron: "0 0 * * *" # daily 00:00 UTC
     workflow_dispatch:
   permissions:
     contents: write
   jobs:
     update:
       uses: rkrug/zenodo-openalex-collection/.github/workflows/collection.yml@v2
       with:
         title: My Community OpenAlex Collections
       secrets:
         API_ZENODO_RO: ${{ secrets.API_ZENODO_RO }}
         API_OPENALEX_PERSONAL: ${{ secrets.API_OPENALEX_PERSONAL }}
   ```

   The secrets must be passed explicitly: `secrets: inherit` only works within the same
   organisation. Optional inputs: `config` (default `config.yml`), `title`, `readme` (default `README.md`),
   `full` (re-download everything; a checkbox on the Actions page in the template).

4. **Add two repository secrets** (Settings → Secrets and variables → Actions):

   | Secret | What |
   |---|---|
   | `API_ZENODO_RO` | Zenodo personal access token ([zenodo.org/account/settings/applications](https://zenodo.org/account/settings/applications)), no write scopes needed. Allows 100 instead of 25 records per page. |
   | `API_OPENALEX_PERSONAL` | **Personal** OpenAlex API key. Collections are created in this account; organisation keys are refused for collections. |

5. **Run it**: Actions → *Update collections* → *Run workflow*. Afterwards it runs daily.

## Data and runs

- **Data** (`output/`: the Zenodo records as parquet files per month, the collection
  record) and the targets store (`_targets/`) are kept in `data-*` releases of your
  repository, not in git. Each run restores the newest one and publishes a new one only
  when `output/` changed; the 3 newest are kept.
- **Zenodo allows 30 search requests per minute** (also with a token). The pipeline
  spaces requests at 2.2 s.
- **`interval`** sets the size of the intervals that are counted every run and
  re-downloaded when their count changed:

  | `interval` | Check (2013 to today) | A change re-downloads | Missed: addition + removal of the same number of versions within the same … |
  |---|---|---|---|
  | `week` | ~620 requests, ~23 min | that week | week |
  | `month` | ~170 requests, ~6 min | that month | month |
  | `quarter` | ~56 requests, ~2 min | that quarter | quarter |
  | `year` (default) | ~14 requests, ~30 s | that year | year |
  | `all` | 1 request | everything | range |

  Use `year` or `all` for small communities that change rarely.
- **`recheck`** (optional, per entry): counts Zenodo and the cached data in a finer
  `recheck: interval` and re-downloads every storage interval that overlaps a changed
  finer interval (a week across a month end marks both months). This catches changes
  that cancel out within an interval. Two forms, exactly one per entry:
  - **`per_run: n`** (rolling, recommended): each run rechecks the next `n` finer
    intervals of the entry in chronological order and starts again at the beginning
    after the end. The extra cost per run is `n` requests; all finer intervals are
    covered every (number of finer intervals ÷ `n`) runs. Set larger values for entries
    that change more often (e.g. the newest range) and small ones for old ranges.
  - **`every: week|month|quarter|year`** (full, **use with caution**): all finer
    intervals at once when due, e.g. ~170 requests (~6 min) for a monthly recheck since
    2013, ~620 (~23 min) for a weekly one, on top of the normal check.

  The state (date, last finer interval checked) is kept with the data
  (`output/<name>/zenodo_recheck.json`), so a failed recheck is repeated on the next run.
  Without `recheck`, no thorough check is done.
- **Full re-download**: Actions → *Update collections* → *Run workflow* → tick
  *Re-download everything from Zenodo* (needs the `full` input from
  [`template/update.yml`](template/update.yml) in your workflow). Scheduled runs never
  re-download everything. Very large communities take longer than GitHub's 6-hour
  limit; run those locally with `ZOC_FULL=true`.
- Consecutive changed
  intervals are downloaded together (up to 10,000 records per query), at 100 records per
  request. Changing `interval` later re-downloads everything once.
- **OpenAlex**: building the collection costs about one credit per 200 found works.

## Large communities

- **Collections**: at most 1,000,000 members, but a collection with more than
  **300,000 members cannot be used as a filter** in OpenAlex queries. Split the community
  into several entries with `from` / `to` (Zenodo creation date) of fewer than
  ~250,000 deposits each, and keep the open-ended last range small. Each deposit belongs
  to the range in which its first version was created.
- **Initial build**: ~100 records per request at 27 requests per minute is about
  160,000 records per hour; more than GitHub's 6-hour job limit for very large
  communities. Run the first build locally (below) and upload the result as a release:

  ```sh
  tag="data-$(date -u +%Y%m%d-%H%M%S)"; mkdir upload
  for d in output/*/; do n=$(basename "$d"); COPYFILE_DISABLE=1 tar -czf "upload/output_$n.tar.gz" "output/$n"; done
  COPYFILE_DISABLE=1 tar -czf upload/targets.tar.gz _targets
  find output -type f -print0 | sort -z | xargs -0 shasum -a 256 > upload/MANIFEST.sha256
  gh release create "$tag" --title "$tag" --notes "Initial build" --latest=false upload/*
  ```

## Local runs

In your community repository, with this repository checked out next to it:

```r
Sys.setenv(ZOC_CODE_DIR = "../zenodo-openalex-collection")
targets::tar_make(script = "../zenodo-openalex-collection/_targets.R")
```

API keys are read from the environment variables `API_zenodo_ro` and
`API_openalex_personal`, or from keyring entries with these names. Packages:
`targets`, `tarchetypes`, `yaml`, `httr2`, `arrow`, `dplyr`, `jsonlite` and
[`openalexPro`](https://openalexpro.r-universe.dev) (≥ 0.18.0).

Don't run the same configuration locally and on GitHub at the same time: both work on
the same OpenAlex collection.

## Versions

Callers reference `@v2` (or `@v1`). `v2` adds the interval `week`, the rolling recheck
(`per_run`) and deposits without a Zenodo concept DOI; every configuration that works with
`v1` works unchanged with `v2`. Changes are developed on `main` and tested locally with
`source("tests/run_local_test.R")` (from the repository root; uses the OpenAlex key
`API_openalex_github_test`) and on GitHub with the manual
[Test](.github/workflows/test.yml) workflow (a small range in a test collection; keeps no
data). The `v2` tag is moved to a tested commit to release a change to all callers;
changes that break existing configurations get a new major version (`v3`).
Reference `@main` to always use the latest code.

## Citation and license

Please cite this software as given in [CITATION.cff](CITATION.cff) (GitHub: *Cite this
repository*). Releases are archived on Zenodo:
[10.5281/zenodo.24370578](https://doi.org/10.5281/zenodo.24370578) (all versions; resolves
to the newest). Licensed under the [MIT License](LICENSE).
