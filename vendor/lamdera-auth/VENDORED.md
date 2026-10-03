Vendored from https://github.com/lamdera/auth at commit 2215675fada642b69bbb2754759438d4960ee80f

This is a non-package Elm library; copy-vendored into vendor/lamdera-auth/src
and referenced from elm.json:source-directories.

## Local patches

Search for `LOCAL PATCH` to find divergences from upstream.

- **src/Auth/Method/OAuthGithub.elm** — dropped `user:email` scope and removed
  the `/user/emails` fallback in `getUserInfo`. Upstream required either a
  public primary email or `user:email` scope; we accept an empty email and
  identify users by `login`/`name` from the `/user` endpoint.
