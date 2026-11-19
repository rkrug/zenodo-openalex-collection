# zenodo-openalex-collection

Keeps an [OpenAlex collection](https://openalex.org) of the deposits in a
[Zenodo community](https://zenodo.org/communities) up to date, using a GitHub Action
that runs in **your** repository.

- All versions of all deposits in the community are downloaded from Zenodo.
- The OpenAlex collection is built from the **concept DOIs** (they always resolve to the
  newest version, and OpenAlex uses them as the main DOI of the merged work), searching
  all OpenAlex corpora (core + expansion — most Zenodo deposits are only in the expansion).
- Each run counts the community's records per month on Zenodo and downloads only the
  months that changed. The collection keeps its ID; members are added and removed.
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
       uses: rkrug/zenodo-openalex-collection/.github/workflows/collection.yml@v1
       with:
         title: My Community OpenAlex Collections
       secrets: inherit
   ```

   Optional inputs: `config` (default `config.yml`), `title`, `readme` (default `README.md`).

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
  spaces requests at 2.2 s. The daily check costs one request per month of the range
  (2013 to today: ~170 requests, ~6 min). A changed month adds ~2 requests per 100 records.
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

Callers reference `@v1`. Changes are developed on `main` and tested with the manual
[Test](.github/workflows/test.yml) workflow (a small range in a test collection; keeps no
data). The `v1` tag is moved to a tested commit to release a change to all callers;
changes that need something new from callers (e.g. a new config field) get `v2`.
Reference `@main` to always use the latest code.
