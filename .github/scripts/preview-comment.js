// Upserts the sticky Lamdera preview comment on a PR. Called from
// .github/workflows/preview.yml twice: once as soon as the preview deploy is
// done (screenshots "pending"), and again when the screenshot job finishes.
module.exports = async ({ github, context }) => {
  const marker = '<!-- lamdera-preview -->';
  const pr = context.payload.pull_request;
  const sha = pr.head.sha;
  const runUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
  const env = process.env;

  const lines = [marker, `### Lamdera preview for \`${sha.slice(0, 7)}\``, ''];
  if (env.DEPLOY_RESULT === 'success') {
    lines.push(`**Preview:** ${env.PREVIEW_URL}`);
    if (!env.PREVIEW_SLOT) {
      lines.push('', '_All 5 preview slots are held by other unmerged PRs, so this URL probably isn\'t served (only the slots have Lamdera config). Close or merge a PR to free a slot, then push again._');
    }
    lines.push('', '_Lamdera builds the preview after the push, so it may take a minute to update. Preview backends reset on every deploy._');
  } else {
    lines.push(`**Preview:** ❌ deploy ${env.DEPLOY_RESULT} ([logs](${runUrl}))`);
  }
  lines.push('');
  if (env.SHOTS_RESULT === 'pending') {
    lines.push('**Screenshots:** ⏳ taking them now; this comment updates when they are ready.');
  } else if (env.SHOTS_RESULT === 'success' && env.SHOTS_COMMIT) {
    const base = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/blob/${env.SHOTS_COMMIT}/pr-${pr.number}/${sha}`;
    const files = env.SHOTS_FILES.split(',').filter(Boolean);
    lines.push('<details><summary>Screenshots (local <code>lamdera live</code>)</summary>', '');
    for (const f of files) lines.push(`**${f.replace(/\.png$/, '')}**`, '', `<img src="${base}/${f}?raw=true" width="400">`, '');
    lines.push('</details>');
  } else {
    lines.push(`**Screenshots:** ❌ ${env.SHOTS_RESULT} ([logs](${runUrl}))`);
  }
  const body = lines.join('\n');

  const { data: comments } = await github.rest.issues.listComments({
    ...context.repo, issue_number: pr.number, per_page: 100,
  });
  const existing = comments.find((c) => c.body && c.body.includes(marker));
  if (existing) {
    await github.rest.issues.updateComment({ ...context.repo, comment_id: existing.id, body });
  } else {
    await github.rest.issues.createComment({ ...context.repo, issue_number: pr.number, body });
  }
};
