// Helpers

const toGitUrl = () =>
  document.location.href
    .replace(/https?:\/\//, "git@")
    .replace(/$/, '/');

const extractRepoPath = (url) =>
  /.*?\/.*?\/.*?(?=\/)/.exec(url)[0];

const formatGitPath = (path) =>
  path.replace("/", ":")
    .replace(/$/, ".git");

const getRepositoryUrl = () =>
  formatGitPath(extractRepoPath(toGitUrl()));

const getPullRequestNumber = () => {
  const match = document.location.pathname.match(/\/pull\/(\d+)/);
  return match ? match[1] : null;
};

// Commands

const getCloneCommand = (prefix = "") =>
  `${prefix}${getRepositoryUrl()}`;

const getForkCloneCommand = () =>
  getCloneCommand("gfc ");

const getUpstreamCloneCommand = () =>
  getCloneCommand("gfc -o upstream ");

tri.commands = {
  getCloneCommand,
  getForkCloneCommand,
  getUpstreamCloneCommand,
  getPullRequestNumber
};
