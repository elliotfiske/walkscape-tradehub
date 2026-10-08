// Picks the preview slot (a-e) for a PR. Called from .github/workflows/preview.yml.
//
// Discord only accepts redirect URIs registered in its Developer Portal, so
// previews can't live at an arbitrary `<app>-pr-<N>.lamdera.app`. Instead there
// are a fixed number of slots, `<app>-pr-a` .. `<app>-pr-e`, each registered in
// Discord as `https://<app>-pr-<slot>.lamdera.app/login/OAuthDiscord/callback`.
//
// A slot is held by an unmerged PR (open or draft) carrying the label
// `preview-slot-<slot>`; closing or merging the PR frees it. Preview backends
// reset on every deploy and skip Evergreen, so handing a slot to a new PR needs
// no cleanup. A PR keeps its slot across pushes, and takes the first free one
// when it has none. With no free slot it gets '' and the caller falls back to
// `pr-<N>` (which has no Lamdera config and probably isn't served).
const SLOTS = ['a', 'b', 'c', 'd', 'e'];
const LABEL_PREFIX = 'preview-slot-';

const slotOfLabels = (labels) => {
  for (const { name } of labels) {
    if (name.startsWith(LABEL_PREFIX) && SLOTS.includes(name.slice(LABEL_PREFIX.length))) {
      return name.slice(LABEL_PREFIX.length);
    }
  }
  return '';
};

// `others` are the other unmerged PRs: [{ number, slot }]. A PR may keep a slot
// unless a lower-numbered PR holds it too, which is how two PRs that raced for
// the same slot are told apart: the lower number wins, the other picks again.
const mayKeep = (number, slot, others) =>
  !others.some((p) => p.slot === slot && p.number < number);

// Keeps `mine` if allowed, otherwise the first slot nobody holds, otherwise ''.
const pickSlot = (number, mine, others) => {
  if (mine && mayKeep(number, mine, others)) return mine;
  const taken = new Set(others.map((p) => p.slot));
  return SLOTS.find((s) => !taken.has(s)) || '';
};

const claim = async ({ github, context, core }) => {
  const { owner, repo } = context.repo;
  const number = context.payload.pull_request.number;

  const unmergedPrs = async () => {
    const prs = await github.paginate(github.rest.pulls.list, { owner, repo, state: 'open', per_page: 100 });
    return prs.map((p) => ({ number: p.number, slot: slotOfLabels(p.labels) }));
  };
  const setSlot = async (from, to) => {
    if (from === to) return;
    if (from) {
      await github.rest.issues
        .removeLabel({ owner, repo, issue_number: number, name: LABEL_PREFIX + from })
        .catch(() => {});
    }
    if (to) {
      await github.rest.issues
        .createLabel({ owner, repo, name: LABEL_PREFIX + to, color: 'c5def5', description: `Preview slot ${to} (Discord redirect URI registered)` })
        .catch(() => {}); // already exists
      await github.rest.issues.addLabels({ owner, repo, issue_number: number, labels: [LABEL_PREFIX + to] });
    }
  };

  let current = '';
  for (let attempt = 0; attempt < 4; attempt++) {
    const prs = await unmergedPrs();
    const me = prs.find((p) => p.number === number);
    const others = prs.filter((p) => p.number !== number);
    current = me ? me.slot : current;
    const slot = pickSlot(number, current, others);
    await setSlot(current, slot);
    current = slot;
    if (!slot) break;
    // Let a simultaneous claimer's label land, then check we really own it.
    await new Promise((resolve) => setTimeout(resolve, 3000));
    const after = (await unmergedPrs()).filter((p) => p.number !== number);
    if (mayKeep(number, slot, after)) break;
    core.info(`slot ${slot} was claimed by a lower-numbered PR at the same time; retrying`);
  }

  core.info(current ? `PR #${number} uses preview slot ${current}` : `PR #${number}: no free preview slot`);
  return current;
};

module.exports = { SLOTS, slotOfLabels, mayKeep, pickSlot, claim };
