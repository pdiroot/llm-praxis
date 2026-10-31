Deploy to production. First check that "https://test.playground.localhost" shows the commit of the merge.

Then start the manual job with `glab ci trigger deploy-prod -b main` and follow it with `glab ci trace`. The binary is the artifact that test got.

Report the job status, the last lines of the log, and the commit that "https://prod.playground.localhost" shows.
