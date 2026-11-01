require'data/dict'
coclass 'peasydict'
NB. Create easydict object. This defers creation of the underlying dictionary object and infers key/value types and shapes from the first put.
NB. Parameters (as for the data/dictionary addon) are given as a string with ; separating options.
NB. backingdict stores backing jdict. Before the first put, methods are placeholders. After the first put, they are inherited from the backing dict.
NB. Currently not supported: params taking gerunds as values (keycompare, keyhash).
NB. TODO
NB. - integrate sym creation
NB. - implement shorthand options (e.g. ks=keyshape).

create =: {{)m
  par =. (<,';') cut ;: y                  NB. split argument string in chunks by ; after 
  dicttype  =: ;: inv 0 {:: par            NB. boxed dict type
  params =: (]`[@.(_-:])&.> _&".&.>) > }. par NB. Assumes all keyword/value params are paired, and valid J words.
  if. (#params)>namei=.'name' i. {."1 params do. 
    name=: namei {:: {:"1 params
  else.
    name=:'' 
  end.
  NB. if all key/val types&shapes defined, just create the dictionary
  if. *./ ({."1 params) e. <;._1 ' keytype keyshape valuetype valueshape' do.
    createdict''
  else. NB. lazy dictionary; infer key/value type/shape from first insert.
  if. name -: '' do. prefix =. suffix =. '' else. 'prefix suffix' =. (,{:)&.>/\. split_name name end.

  (prefix , 'put' , suffix) =: ''&$: : {{ NB. Place-holder for lazy creation of dictionary.
  NB. Set key type shape from first insert keys (and values if provided)
  NB. Note 0: This overwrites any previously set key/val type/shape.
  NB.     Alternatively: check for compliance with ones that did get set upon creation.
  NB. Note 1: This addon chooses to use items of both keys and values as items in the dictionary. Alternatively, one could consider both a single item
  NB.    Either case, if not specified explicitly, one or the other behaviour should be chosen.
  'y must be non-empty' assert y -.@:-: ''
  params =: params,('keytype';'keyshape'),. (3!:0 ; }.@$) y
  if. x-:'' do.
    params =: params,('valuetype';'valueshape'),. 4 ; 0     NB. No values provided, set default type/shape
  else.
    params =: params,('valuetype';'valueshape'),.(3!:0 ; }.@$) x
  end.
  params =: (#~ (~:&.|. *. a:~:])@:({."1)) params NB. Keep only most recent version of params and ensure no spurious empty param names.
  createdict''
  x put__backingdict y
}}
  NB. Other method, for all dict types.
  NB. TODO: check whether defaults before allocation make sense for hash,tree & sym.
  (prefix , 'get' , suffix)   =: (err =. 'easydict not active; put first entry before use'&assert@:0:) f. NB. Others just error.
  (prefix , 'has' , suffix)   =: 0"_1 NB. Sensible defaults for del/has/count for empty dict.
  (prefix , 'count' , suffix) =: 0:
  (prefix , 'items' , suffix) =: ,~ a:
  if. -. issym do.
    (prefix , 'del' , suffix)   =: 0"_1
  end.
  if. 'tree' e. >dicttype do. NB. methods for tree dicts only
    (prefix , 'mget' , suffix) =: err f.
    (prefix , 'min' , suffix) =: 13!:8@6 NB. stock does index error instead.
    (prefix , 'max' , suffix) =: 13!:8@6
    (prefix , 'after' , suffix) =: err f.
    (prefix , 'since' , suffix) =: err f.
    (prefix , 'before' , suffix) =: err f.
    (prefix , 'until' , suffix) =: err f.
    (prefix , 'range' , suffix) =: err f.
    (prefix , 'audittree', suffix) =: err f. NB. not official interface anyhow...
  else. NB. methods for hash dicts only (currently empty, for future use).
  end.
end.
EMPTY
}}
  
createdict =: {{       NB. split off actual dictionary noun creation.
  backingdict =: (dicttype,&<params) conew 'jdict'
  if. name -: '' do. prefix =. suffix =. '' else. 'prefix suffix' =. (,{:)&.>/\. split_name name end.
  NB. Erase all verbs defined before, so ones of parent dict are called.
  erase (prefix,],suffix"_)&.>&.;: 'get del has count mget min max after since before until range audittree'
  (prefix,'put',suffix) =: ''&$: : put__backingdict NB. give put a monadic meaning of omitted values.
  coinsert backingdict NB. make available all verbs defined in created backing dict.
  EMPTY
}}

destroy =: {{
  if. 0<:nc <'backingdict' do. destroy__backingdict'' end. NB. destroy backing dict first, if existing.
  codestroy y  NB. destroy the locale, freeing everything
}}

NB. y is string representing a name with possibly specified locale. Returns two boxes: name ; suffix with locale.
NB. Right part of hook.
NB. If '_' is the last character of y then the name has explicitly specified locale, so get the indexes of '_'.
NB. Left part of hook.
NB. Use the indexes to split the name or if the number of indexes is less than 2 then suppose name is from base.
NB. Note that number of indexes may be smaller then number of '_' e.g. 0 when condition from right part of the hook was false.
split_name =: ('__' ,~&< [)`(({. ,&< }.)~ _2&{)@.(2 <: #@])  ''"_`([: I. '_'&=)@.('_' -: {:)


NB. psym implements symbol tables; Old s: and s: inv correspond roughly to
NB. sym__obj and dat__obj. sym__obj takes boxed data and returns symbol
NB. indices, dat reverses this operation.
NB. Shape is preserved.
NB. Note: need backmap if values  to be adapted based on deleted symbols.
coclass'psym'
issym =: 1
coinsert'peasydict' NB. Inherit from from peasydict

NB. TODO: review what to keep here. Lot's of bookkeeping for deletions and reverse mapping.
NB. Remove deletion.
NB. Could well replace with index into items, if we'd be allowed a reverse mapping at least for syms. Must be possible as "items" is provided as well.
NB. For now, index into items (sorting guaranteed).

NB. Get symbol number for boxed array of data; add to dict and store if not known yet. Like old s: but extended for any data.
NB. Data can be any (boxed) datatype, and boxed array can have any shape; shape is maintained for returned symbols.

NB. Design choices
NB. - as dicts don't allow references to data stored therein, sym & dat do the heavy lifting of storing all data in, and getting it from an array, respectively.
NB. - no deletion
dat =: get { items@'' NB. Likely inefficient but only way without reverse indexing.
sym =: (get [ put) :. dat NB. now puts all inputs; could check with new @. partitioning behaviour if slower or not.
NB. Export wrappers for EasyDicts and symbols to the z locale.

NB.*v easydict_z_: Create easydict. y: options as single, ;-separated string.
easydict_z_=:conew&'peasydict'
NB.*v symbols_z_: Create symbol table. Ignores y.
symbols_z_ =:''&conew@'psym'

NB. Future:
NB. TODO: grading & sorting. Benchmark 2 solutions: 1 doing lookup of sym in data, then sort by lookup selected data in dict
NB. TODO: MISSING: GRADE of given keys.
NB. grade takes symbols and returns them in ascending order
NB. grade =: ((~.i.])@(i.!.0)~ ([ { [: grad@dat ~:@[#]) ])
NB.   this would require reverse lookup; sym into keys for sorting; could be emulated having 2 dicts per symbol table though...
NB. TODO: persistence (once available unloading/loading working for dictionaries)


NB. Memoizing. TODO: check whether still compatible.
cocurrent 'pmem'
coinsert'peasydict'
NB. create pmem: args:#arg dicts,[boxResult,boxMonad/X,boxY]. [] optional, each is 1 if missing. #argdicts indicates whether x,y stored directly with results (0), separately in 1 (x and y) or 2 dictionaries (1 for x, one for y).
NB. If 1 argument dict used, boxing for x&y should be the same.
NB. combination 1 x 1 1 probably makes little sense, but 1 x 0 0 would avoid boxing, especially for same shape&type arguments. note that this would lead to x and y being combined, incurring any filling & type conversion as by ,: .
NB. TODO bugs:
NB. - Boxed result version keeps adding spurious 1's in the result shape.
create =: {{
  y=. 4{.!.1 y NB. default 0 1 1 1
  dr =: conew&'peasydict' 'hash concurrent'
  assert. (1~:{.y) +. =/_2{.y NB. if. only 1 arg dict, both x&y must have same boxing status.
  '`br bx by'=: <^:(1&{y)`(<^:(2&{y))`(<^:(3&{y))
  NB. set verbs for put monadic & put dyadic
  if. 0={.y do.
    pm =: (a:,<@])^:(1{y) NB. box with a: if requested
    pd =: ,:`(,&<)@.(1{y) NB. laminate if not boxed, else ,&<
    dx =: dr [ dy=:dr     NB. for easy destroying; won't be used.
  else. 
    dy =: conew&'idict' 'hash concurrent'
    pm =: _1 , pg__dy@bx f. NB. monad args always in y, use bx, prepend _1 to allow storing monad&dyad in same dict if needed (slight overhead).
    if. 1={.y do.
      pd =: (pg__dy@bx , pg__dy@by) f. NB. 1 argdict, store in dy
      dx =: dr NB. not used; for easy destroying, dx must exist
    else. 
      pd =: (pg__dx@bx , pg__dy@by) f.
      dx =: conew&'idict' 'hash concurrent'
    end.
  end.
  M =: {{
  NB. TODO: somehow, if $: used, only end result is saved, not intermediates because $: then refers to u, i.e. without memorizing... would need to do complicated amend in atomic rep to apply M to $:'s, but not to entire verb, as that would lead to infinite recursion.
    e =. pm y NB. encode inputs
    if. count__dr '' do.
      if. has__dr e do.br^:_1 get__dr e else. e (][(put__dr~ br)) u. y end.
    else. NB. no items yet
      e (][(put__dr~ br))&,: u. y NB. ,: for easydict's first item
    end.
  :
    e =. x pd y NB. encode inputs
    if. count__dr '' do.
      if. has__dr e do.
        br^:_1 get__dr e else.
        e (][(put__dr~ br)) x u. y end.
    else.
      e (][(put__dr~ br))&,: x u. y NB. ,: for easydict's first item
    end.
  }}
  0 0$0
  }} 
NB. no extra locking needed: all dict calls are already threadsafe. Worst case scenario: missing entry being needlesly repeated because another thread was already processing the same.
zap =: {{ NB. remove all results by deleting and recreating dict.
  for_o. ~.dr,dx,dy do. destroy__o'' end.
  create ''
}}
destroy=: {{
  for_o. ~.dr,dx,dy do. destroy__o'' end.
  codestroy y
}}

Note 'Comparison M. & pmem'
)
cocurrent'base'
boxdraw_j_ 1
tst1=:{{
  metric =: 6!:2`(7!:2)@.('space'-:y)
  mettxt =: 'space: '"_^:('space'-:y)'time :'
  a=: conew&'pmem' x
  fibo =: 3 : 'if. 1>:y do. x: y else. (fibo y-1)+fibo(y-2)end.'     "0
  fibm =: 3 : 'if. 1>:y do. x: y else. (fibm y-1)+fibm(y-2)end.' M.  "0
  fibp =: 3 : 'if. 1>:y do. x: y else. (fibp y-1)+fibp(y-2)end.' M__a"0
 
  NB. timex rather than timespacex as the latter first runs space, illing the cache so the timing is meaningless
  echo' orig     ',mettxt,":metric 'fibo 32'
  echo' M.   1st ',mettxt,":metric 'fibm 32'
  echo' M.   2nd ',mettxt,":metric 'fibm 32'
  echo' pmem 1st ',mettxt,":metric 'fibp 32'
  echo' pmem 2nd ',mettxt,":metric 'fibp 32'
NB.   destroy__a''
}}
tst2=:{{
  metric =: 6!:2`(7!:2)@.('space'-:y)
  mettxt =: 'space: '"_^:('space'-:y)'time :'
  a=: conew&'pmem' x
  pno =: -/@(+/)@:($:"0)@rec ` (x:@(0&=)) @. (0>:])
  pnm =: -/@(+/)@:($:"0)@rec ` (x:@(0&=)) @. (0>:]) M.
  pnp =: -/@(+/)@:($:"0)@rec ` (x:@(0&=)) @. (0>:]) M__a
  rec=: - (-: (*"1) _1 1 +/ 3 * ]) @ (>:@i.@>.@%:@((2%3)&*))
  NB. timex rather than timespacex as the latter first runs space, illing the cache so the timing is meaningless
  echo' orig     ',mettxt,":metric 'pno 28'
  echo' M.   1st ',mettxt,":metric 'pnm 28'
  echo' M.   2nd ',mettxt,":metric 'pnm 28'
  echo' pmem 1st ',mettxt,":metric 'pnp 28'
  echo' pmem 2nd ',mettxt,":metric 'pnp 28'
NB.   destroy__a''
}}
tst3=:{{
  metric =: 6!:2`(7!:2)@.('space'-:y)
  mettxt =: 'space: '"_^:('space'-:y)'time :'
  a=: conew&'pmem' x
  combo =: 4 : 'if. (x>:y)+.0=x do. i.(x<:y),x else. (0,.x combo&.<: y),1+x combo y-1 end.'
  combm =: 4 : 'if. (x>:y)+.0=x do. i.(x<:y),x else. (0,.x combm&.<: y),1+x combm y-1 end.' M.
  combp =: 4 : 'if. (x>:y)+.0=x do. i.(x<:y),x else. (0,.x combp&.<: y),1+x combp y-1 end.' M__a
  NB. timex rather than timespacex as the latter first runs space, illing the cache so the timing is meaningless
  echo' orig     ',mettxt,":metric '8 combo 16'
  echo' M.   1st ',mettxt,":metric '8 combm 16'
  echo' M.   2nd ',mettxt,":metric '8 combm 16'
  echo' pmem 1st ',mettxt,":metric '8 combp 16'
  echo' pmem 2nd ',mettxt,":metric '8 combp 16'
  NB. destroy__a''
}}
