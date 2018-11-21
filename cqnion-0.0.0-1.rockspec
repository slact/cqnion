package = "cqnion"
version = "scm-0"

description = {
  summary = "cqueues-based worker threads + a master + tools for the to communicate",
  homepage = "https://github.com/slact/cqnion",
  license = "MIT"
}

source = {
  url = "git+https://github.com/slact/cqnion.git"
}

dependencies = {
  "lua >= 5.1",
  "cqueues >= 20161214"
}

build = {
  type = "builtin",
  modules = {
    ["cqnion.master"] = "cqnion/master.lua",
    ["cqnion.worker"] = "cqnion/worker.lua",
    ["cqnion.messenger"] = "cqnion/messenger.lua",
    ["cqnion.util"] = "cqnion/util.lua",
  };
}
