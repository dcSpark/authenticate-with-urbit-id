/-  *resource, gs=graph-store, gspost=post
/+  default-agent, dbug, sig=signatures
|_  =bowl:gall
+$  add-nodes-action  [%add-nodes =resource nodes=(map index:gspost node:gs)]
++  build-dm
  |=  [target=@p contents=(list content:gspost)]
  ^-  update:gs
  =/  i=(list atom)  ~[`@`target +(now.bowl)]
  =/  p  (build-post i contents)
  =/  n  (build-node p)
  =/  a  (build-action n [our.bowl %dm-inbox])
  (build-update a)
++  build-post  
  |=  [index=(list atom) contents=(list content:gspost)]
  ^-  post:gspost
  =/  author  our.bowl
  =/  time-sent  now.bowl
  =/  hash  `@ux`(sham [~ author time-sent contents])
  =/  signature  (sign:sig our.bowl now.bowl hash)
  [author=author index=index time-sent=time-sent contents=contents hash=(some hash) signatures=(sy signature^~)]
++  build-node
  |=  [post=post:gspost]
  ^-  node:gs
  [post=[%& p=post] children=[%empty ~]]
++  build-action
  |=  [node=node:gs =resource]
  ^-  action:gs
  ?>  ?=(%& -.post.node)
  =/  post  `post:gs`+.post.node
  =/  index  index.post
  =/  map  (my ~[[index node]])
  [%add-nodes resource=resource nodes=map]
++  build-update
  |=  [action=action:gs]
  ^-  update:gs
  [p=now.bowl q=action]
++  build-poke-card
    |=  [reply=update:gs =resource]
    ^-  card
    =/  cage  `cage`[%graph-update-3 !>(reply)]
    =/  task  `task:agent:gall`[%poke cage]
    =/  ship  
    ?:  .=(our.bowl entity.resource) 
      `[@p @tas]`[our.bowl %graph-store] 
      `[@p @tas]`[our.bowl %graph-push-hook] 
    :: =/  ship  `[@p @tas]`[our.bowl %graph-push-hook]  ::  this fucks things up if the bot is hosting the group
    =/  note  `note:agent:gall`[%agent ship task]
    =/  wire  `wire`/graph-store-bottest  :: apparently must be the same as the subscription wire
    =/  card  `card`[%pass wire note]
    card
++  update-from-cage
  |=  =cage
  ^-  update:gs
  =/  mark  p.cage
  =/  vase  q.cage
  `update:gs`!<(=update:gs vase)
++  action-from-update
  |=  =update:gs
  ^-  (unit add-nodes-action)
  =/  action=action:gs  q.update
  ?+  action  ~
  [%add-nodes *] 
    `action
  ==
++  starts-with
    |=  [str=tape nedl=tape]
    ^-  ?
    ::TODO  find vs scag & compare?
    =((find nedl str) [~ 0]) 
++  resource-from-action
  |=  =add-nodes-action
  ^-  resource
  resource.add-nodes-action
++  node-from-action
  |=  =add-nodes-action
  ^-  (unit node:gs)
  =/  nodes  nodes.add-nodes-action
  =/  values  ~(val by nodes)
  ?~  values  ~  
  `i.values
++  post-from-node
  |=  =node:gs
  ^-  (unit post:gspost)
  ?:  ?=(%& -.post.node)  :: this checks for maybe-post, i.e. deleted posts
  `+.post.node
  ~
++  index-from-post
  |=  =post:gspost
  ^-  index:gspost
  index.post
++  author-from-post
  |=  =post:gs
  ^-  ship
  author.post
++  contents-from-post
  |=  =post:gs
  ^-  (list content:gspost)
  contents.post
++  time-from-post
  |=  =post:gs
  ^-  time
  time-sent.post
++  extract-first-text
  |=  contents=(list content:gspost)
  ^-  (unit @t)
  ?+  i.-.contents  ~
  [%text *]
    `text.i.-.contents
  ==
:: with thanks to ~hosted-fornet crunch library
++  contents-to-cord
 |=  contents=(list content:gspost)
 ^-  @t
 ?~  contents
   ''
 %+  join-cords
   ' '
 (turn contents content-to-cord)
  ::
++  content-to-cord
  |=  =content:gspost
  ^-  @t
  ?-  -.content
    %text       text.content
    %mention    (scot %p ship.content)
    %url        url.content
    %code       expression.content    :: TODO: also print output?
    %reference  'reference'::(reference-content-to-cord reference.content)
    :: references must be scried and displayed as such
  ==
  ++  join-cords
    |=  [delimiter=@t cords=(list @t)]
    ^-  @t
    %+  roll  cords
    |=  [cord=@t out=@t]
    ^-  @t
    ?:  =('' out)
      :: don't put delimiter before first element
      ::
      cord
    (rap 3 out delimiter cord ~)  
  ::
++  reference-content-to-cord
  |=  =reference:gspost
  ^-  @t
  ?-  -.reference
    %group  (resource-to-cord group.reference)
    %graph  (rap 3 (resource-to-cord group.reference) ': ' (resource-to-cord resource.uid.reference) ~)
    %app    (rap 3 'app: ' (scot %p ship.reference) ' %' (scot %tas desk.reference) ' ' "{<path.reference>}")
  ==
++  resource-to-cord
  |=  =resource  ^-  @t
  =/  t=tape  "{<entity.resource>}/{<name.resource>}"
  (crip t)
++  scry-node
  |=  [=bowl:gall =resource index=@]
  .^
  update:gs 
  %gx 
  (scot %p our.bowl) 
  %graph-store 
  (scot %da now.bowl) 
  %graph
  (scot %p entity.resource) 
  name.resource
  %node
  %index
  %kith
  (scot %ud index)
  /noun
  ==
--