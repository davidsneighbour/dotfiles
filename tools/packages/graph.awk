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
#   HARD_ONLY  1 to follow only hard edges (Pre-Depends and Depends)
#   JSON       why: 1 to print a JSON array instead of text
#   FORMAT     tree: "text" (default) or "dot" for Graphviz
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
    if (JSON == 1) {
      print "["
      for (i = 1; i <= m; i++) {
        why_json(targets[i], i == m)
      }
      print "]"
    } else {
      for (i = 1; i <= m; i++) {
        if (i > 1) {
          print ""
          print ""
        }
        why(targets[i])
      }
    }
  } else if (CMD == "tree" && FORMAT == "dot") {
    tree_dot()
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
# Fills roots[] and next_hop[] and returns the number of roots. With
# hard_only, only hard edges are followed.
function find_roots(target, hard_only, roots, next_hop,    queue, head, tail, seen, nroots, node, m, list, i, parent) {
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
    if (hard_only) {
      m = split(parents_hard[node], list, " ")
    } else {
      m = split(parents_hard[node] parents_soft[node], list, " ")
    }
    for (i = 1; i <= m; i++) {
      parent = list[i]
      if (!(parent in seen)) {
        seen[parent] = 1
        next_hop[parent] = node
        queue[++tail] = parent
      }
    }
  }
  return nroots
}

function why(target,    next_hop, roots, nroots, soft_roots, soft_hops, node, i, shown, indent) {
  print label(target)
  print ""

  nroots = find_roots(target, HARD_ONLY == 1, roots, next_hop)

  # With --depends-only, a package that only soft edges keep is still kept
  # by APT, so do not say that nothing needs it.
  if (nroots == 0 && HARD_ONLY == 1 && find_roots(target, 0, soft_roots, soft_hops) > 0) {
    if (target in manual) {
      print "Marked manual. Other manual or essential packages need it only through Recommends or Suggests."
    } else if (essential[target]) {
      print "Essential. dpkg does not allow removing it."
    } else {
      print "No manual or essential package needs it through Pre-Depends or Depends."
      print "It is needed only through Recommends or Suggests, so APT keeps it."
      print "Run without --depends-only to see these paths."
    }
    return
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

# A JSON string literal. Package names and versions are plain ASCII, but
# escape the JSON specials anyway.
function json_str(text) {
  gsub(/\\/, "\\\\", text)
  gsub(/"/, "\\\"", text)
  gsub(/\t/, "\\t", text)
  return "\"" text "\""
}

# One why result as a JSON object. status is one of: required, soft-only,
# manual, essential, orphaned, kept. Each path goes from the root down to the
# target. --all and the 10-path limit apply as in the text view.
function why_json(target, last,    next_hop, roots, nroots, soft_roots, soft_hops, status, shown, i, node, path, out) {
  nroots = find_roots(target, HARD_ONLY == 1, roots, next_hop)
  if (nroots > 0) {
    status = "required"
  } else if (HARD_ONLY == 1 && find_roots(target, 0, soft_roots, soft_hops) > 0) {
    status = "soft-only"
  } else if (target in manual) {
    status = "manual"
  } else if (essential[target]) {
    status = "essential"
  } else if (target in orphan) {
    status = "orphaned"
  } else {
    status = "kept"
  }
  shown = nroots
  if (MAX_ROOTS > 0 && shown > MAX_ROOTS) {
    shown = MAX_ROOTS
  }
  out = ""
  for (i = 1; i <= shown; i++) {
    node = roots[i]
    path = json_str(node)
    while (node != target) {
      node = next_hop[node]
      path = path "," json_str(node)
    }
    out = out (i > 1 ? "," : "") "[" path "]"
  }
  printf "{\"package\":%s,\"mark\":%s,\"essential\":%s,\"status\":%s,\"total_paths\":%d,\"paths\":[%s]}%s\n", \
    json_str(target), json_str((target in manual) ? "manual" : "automatic"), \
    (essential[target] ? "true" : "false"), json_str(status), nroots, out, (last ? "" : ",")
}

# Graphviz view of the same packages and edges as the text tree. Manual
# packages are filled, essential packages have a double border, Recommends
# edges are dashed, and Suggests edges are dotted.
function tree_dot(    m, list, i, queue, head, tail, depth, seen, node, nc, kids, j, child, kind, style, attrs) {
  if (NAMES == "") {
    m = 0
    for (i = 1; i <= count; i++) {
      if (order[i] in manual) {
        list[++m] = order[i]
      }
    }
  } else {
    m = split(NAMES, list, " ")
  }
  print "digraph packages {"
  print "  rankdir=LR;"
  print "  node [shape=box, fontname=\"sans-serif\"];"
  tail = 0
  for (i = 1; i <= m; i++) {
    if (!(list[i] in seen)) {
      seen[list[i]] = 1
      depth[list[i]] = 0
      queue[++tail] = list[i]
    }
  }
  head = 1
  while (head <= tail) {
    node = queue[head++]
    attrs = ""
    if (node in manual) {
      attrs = "style=filled, fillcolor=\"#c8e6c9\""
    }
    if (essential[node]) {
      attrs = attrs (attrs == "" ? "" : ", ") "peripheries=2"
    }
    print "  " json_str(node) (attrs == "" ? "" : " [" attrs "]") ";"
    if (DEPTH > 0 && depth[node] >= DEPTH) {
      continue
    }
    nc = split(child_list(node), kids, " ")
    for (j = 1; j <= nc; j++) {
      child = kids[j]
      kind = edge_kind[node, child]
      style = ""
      if (kind == 2) {
        style = " [style=dashed, label=\"recommends\"]"
      } else if (kind == 3) {
        style = " [style=dotted, label=\"suggests\"]"
      }
      print "  " json_str(node) " -> " json_str(child) style ";"
      if (!(child in seen)) {
        seen[child] = 1
        depth[child] = depth[node] + 1
        queue[++tail] = child
      }
    }
  }
  print "}"
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

# The children of a node as a space-separated list. With HARD_ONLY, soft
# edges are left out.
function child_list(node,    m, list, i, out) {
  if (HARD_ONLY != 1) {
    return children[node]
  }
  m = split(children[node], list, " ")
  out = ""
  for (i = 1; i <= m; i++) {
    if (edge_kind[node, list[i]] == 1) {
      out = out " " list[i]
    }
  }
  return out
}

# Each package is expanded once. Later occurrences print "(see above)", which
# also stops cycles. In the all-manual view, manual children are not expanded
# because they have their own entry.
function tree_children(node, prefix, depth, all_manual,    m, list, i, child, connector, extension, line) {
  m = split(child_list(node), list, " ")
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
      if (child_list(child) != "") {
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
