# Build the dependency graph of the installed packages and print the `tree`
# or `why` view.
#
# Input files (in this order):
#   1. installed.tsv  dpkg-query rows, sorted by name, with these fields:
#      status, package, essential, version, pre-depends, depends,
#      recommends, suggests, provides
#   2. manual.txt     one manual package name per line (apt-mark showmanual)
#
# Variables:
#   CMD        "tree" or "why"
#   NAMES      space-separated package names (why: targets, tree: roots;
#              an empty value for tree means all manual packages)
#   ORPHANS    space-separated names that APT would autoremove (why only)
#   MAX_ROOTS  why: number of root paths to show, 0 for all
#   DEPTH      tree: maximum depth, 0 for no limit
#   COLOR      1 to colour the labels
#
# An edge "a -> b" means that a needs b. Pre-Depends and Depends are hard
# edges. Recommends and Suggests are soft edges. APT keeps a package for all
# four kinds, so all of them count as a reason why a package is installed.
# Only installed packages are nodes. A dependency on a virtual package links
# to every installed package that provides it, and an alternative ("a | b")
# links to every installed alternative. Version constraints are not checked.

BEGIN {
  FS = "\t"
  KIND_NAME[1] = "depends"
  KIND_NAME[2] = "recommends"
  KIND_NAME[3] = "suggests"
  if (COLOR == 1) {
    C_MANUAL = "\033[32m"
    C_AUTO = "\033[2m"
    C_NOTE = "\033[2m"
    C_RESET = "\033[0m"
  }
}

# Pass 1: installed packages.
FNR == NR {
  if (substr($1, 2, 1) != "i") {
    next
  }
  name = $2
  installed[name] = 1
  order[++count] = name
  essential[name] = ($3 == "yes")
  field[name, 1] = $5 ", " $6
  field[name, 2] = $7
  field[name, 3] = $8
  np = split($9, provided, /, */)
  for (i = 1; i <= np; i++) {
    virtual = dep_name(provided[i])
    if (virtual != "") {
      providers[virtual] = providers[virtual] " " name
    }
  }
  next
}

# Pass 2: manual packages.
{
  sub(/:.*/, "")
  if ($0 != "") {
    manual[$0] = 1
  }
}

END {
  for (i = 1; i <= count; i++) {
    for (kind = 1; kind <= 3; kind++) {
      add_edges(order[i], kind)
    }
  }
  # Parent lists hold hard edges first, so `why` prefers Depends paths.
  for (i = 1; i <= count; i++) {
    parent = order[i]
    m = split(children[parent], list, " ")
    for (j = 1; j <= m; j++) {
      if (edge_kind[parent, list[j]] == 1) {
        parents_hard[list[j]] = parents_hard[list[j]] " " parent
      } else {
        parents_soft[list[j]] = parents_soft[list[j]] " " parent
      }
    }
  }

  if (CMD == "why") {
    split(ORPHANS, list, " ")
    for (i in list) {
      orphan[list[i]] = 1
    }
    m = split(NAMES, targets, " ")
    for (i = 1; i <= m; i++) {
      if (i > 1) {
        print ""
        print ""
      }
      why(targets[i])
    }
  } else if (CMD == "tree") {
    tree_all()
  } else {
    print "graph.awk: unknown CMD: " CMD > "/dev/stderr"
    exit 2
  }
}

# Strip the version constraint and the architecture qualifier from one
# dependency, for example "libc6:any (>= 2.34)" -> "libc6".
function dep_name(text) {
  sub(/^ +/, "", text)
  sub(/[ (].*/, "", text)
  sub(/:.*/, "", text)
  return text
}

function add_edge(from, to, kind) {
  if (from == to) {
    return
  }
  if ((from, to) in edge_kind) {
    if (kind < edge_kind[from, to]) {
      edge_kind[from, to] = kind
    }
    return
  }
  edge_kind[from, to] = kind
  children[from] = children[from] " " to
}

function add_edges(from, kind,    nc, clauses, i, na, alternatives, j, target, nps, provs, k) {
  nc = split(field[from, kind], clauses, /, */)
  for (i = 1; i <= nc; i++) {
    na = split(clauses[i], alternatives, /\|/)
    for (j = 1; j <= na; j++) {
      target = dep_name(alternatives[j])
      if (target == "") {
        continue
      }
      if (target in installed) {
        add_edge(from, target, kind)
      }
      if (target in providers) {
        nps = split(providers[target], provs, " ")
        for (k = 1; k <= nps; k++) {
          add_edge(from, provs[k], kind)
        }
      }
    }
  }
}

function is_root(name) {
  return (name in manual) || essential[name]
}

function label(name,    mark, colour) {
  if (name in manual) {
    mark = "manual"
    colour = C_MANUAL
  } else {
    mark = "automatic"
    colour = C_AUTO
  }
  if (essential[name]) {
    mark = mark ", essential"
  }
  return name " " colour "[" mark "]" C_RESET
}

# " (recommends)" or " (suggests)" for a soft edge, nothing for a hard edge.
function kind_note(from, to,    kind) {
  kind = edge_kind[from, to]
  if (kind > 1) {
    return " " C_NOTE "(" KIND_NAME[kind] ")" C_RESET
  }
  return ""
}

# Search upwards from the target, breadth first, and stop at each root
# (manual or essential package). Each root found gives one shortest path.
function why(target,    queue, head, tail, next_hop, seen, roots, nroots, node, m, list, i, parent, shown, indent) {
  print label(target)
  print ""

  queue[1] = target
  seen[target] = 1
  head = 1
  tail = 1
  nroots = 0
  while (head <= tail) {
    node = queue[head++]
    if (node != target && is_root(node)) {
      roots[++nroots] = node
      continue
    }
    m = split(parents_hard[node] parents_soft[node], list, " ")
    for (i = 1; i <= m; i++) {
      parent = list[i]
      if (!(parent in seen)) {
        seen[parent] = 1
        next_hop[parent] = node
        queue[++tail] = parent
      }
    }
  }

  if (nroots == 0) {
    if (target in manual) {
      print "Marked manual. No other manual or essential package needs it."
    } else if (essential[target]) {
      print "Essential. dpkg does not allow removing it."
    } else {
      print "No manual or essential package needs it."
      if (target in orphan) {
        print "APT would remove it with autoremove (see `packages orphaned`)."
      } else {
        print "APT does not offer it for autoremove (for example, APT protects recent kernels)."
      }
    }
    return
  }

  if (target in manual) {
    print "Marked manual. It is also required through:"
  } else {
    print "Required through:"
  }

  shown = nroots
  if (MAX_ROOTS > 0 && shown > MAX_ROOTS) {
    shown = MAX_ROOTS
  }
  for (i = 1; i <= shown; i++) {
    print ""
    node = roots[i]
    print label(node)
    indent = ""
    while (node != target) {
      print indent "└── " label(next_hop[node]) kind_note(node, next_hop[node])
      indent = indent "    "
      node = next_hop[node]
    }
  }
  if (shown < nroots) {
    print ""
    print "... and " (nroots - shown) " more (use --all to show all)."
  }
}

function tree_all(    m, list, i, all_manual) {
  all_manual = (NAMES == "")
  if (all_manual) {
    m = 0
    for (i = 1; i <= count; i++) {
      if (order[i] in manual) {
        list[++m] = order[i]
      }
    }
  } else {
    m = split(NAMES, list, " ")
  }
  for (i = 1; i <= m; i++) {
    if (i > 1) {
      print ""
    }
    if (list[i] in shown) {
      print label(list[i]) " (see above)"
      continue
    }
    shown[list[i]] = 1
    print label(list[i])
    tree_children(list[i], "", 1, all_manual)
  }
}

# Each package is expanded once. Later occurrences print "(see above)", which
# also stops cycles. In the all-manual view, manual children are not expanded
# because they have their own entry.
function tree_children(node, prefix, depth, all_manual,    m, list, i, child, connector, extension, line) {
  m = split(children[node], list, " ")
  for (i = 1; i <= m; i++) {
    child = list[i]
    if (i == m) {
      connector = "└── "
      extension = "    "
    } else {
      connector = "├── "
      extension = "│   "
    }
    line = prefix connector label(child) kind_note(node, child)
    if (child in shown) {
      print line " (see above)"
      continue
    }
    if (all_manual && (child in manual)) {
      print line
      continue
    }
    if (DEPTH > 0 && depth >= DEPTH) {
      if (children[child] != "") {
        line = line " ..."
      }
      print line
      continue
    }
    shown[child] = 1
    print line
    tree_children(child, prefix extension, depth + 1, all_manual)
  }
}
