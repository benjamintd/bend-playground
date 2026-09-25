import Base

# Safe affine organization oracle. Caller supplies (cell,id) entries; sorting
# is independent of the atomic backend. Only small tests/experiments call this.
type Entry is Data:
  Entry{cell: U32, id: U32}

def le(a: Entry, b: Entry) -> Bool:
  Entry{+ac,ai} = a
  Entry{+bc,bi} = b
  (ac < bc : U32) || (U32.is_eq(ac,bc) && (ai <= bi : U32))

def organize(entries: List<&2,Entry>) -> List<&2,Entry>:
  List.sort(~Entry,~le,entries)
