  ::
::::  hermes.hoon
::
::      %gall agent to authenticate a ship for Urbit Visor.
::
::    The basic architecture is that Visor requests a website running the agent
::    to produce a token and wait for a DM containing the token from the
::    authenticating ship.
::
/-  hermes, graph-store
/+  server, default-agent, dbug, graph-store
|%
+$  versioned-state
    $%  state-zero
    ==
::
+$  state-zero
    $:  [%0 =tokens =status]
    ==
::
+$  url  @t
::
+$  tokens  (map @p tape)
+$  status  (map @p ?(%.y %.n))
::
+$  card  card:agent:gall
::
--
%-  agent:dbug
=|  state-zero
=*  state  -
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    default   ~(. (default-agent this %|) bowl)
    main     ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%hermes initialized successfully'
  =.  state  [%0 *(map @p tape) *(map @p ?(%.y %.n))]
  :_  this
  :~  [%pass /bind %arvo %e %connect [~ /'~initiateAuth'] %hermes]
      [%pass /bind %arvo %e %connect [~ /'~checkAuth'] %hermes]
  ==
++  on-save
  ^-  vase
  !>(state)
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  =/  prev  !<(versioned-state old-state)
  ?-  -.prev
    %0
    ~&  >>>  '%0'
    `this(state prev)
  ==
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  =^  cards  state
    ?+    mark  (on-poke:default mark vase)
        %hermes-action  (handle-action !<(action:hermes vase))
        %handle-http-request
      =+  !<([id=@ta =inbound-request:eyre] vase)
      ?:  =(url.request.inbound-request '/~initiateAuth')
        ::
        :: Inputs:
        ::   Urbit ship to authenticate @p: String
        ::
        :: Outputs:
        ::   Auth code: String
        ::   Ship @p (our): String
        ::
        :: Side Effects:
        ::   Stores the auth code, @p of ship to be authenticated, and false
        ::   (as the current auth status) in the ship locally.
        ::   Creates a subscription to graph-store that watches for DMs to come
        ::   from the input ship @p. If a DM comes through with the auth code
        ::   then update the auth status of the ship in the gall app to true.
        ::
        :: Description:
        ::   This generates a random alphanumeric auth code, stores it in the
        ::   ship with the @p of the ship wanting to be authenticated, and an
        ::   "auth status" field that defaults to false. This endpoint returns
        ::   the auth code + the @p of the ship that is running the gall app
        ::   to the caller.
        ::
        ::   Thenceforth the gall app should watch for all DMs through graph-
        ::   store and if a DM comes from a registered @p and has the same auth
        ::   code as stored, then switch the "auth status" value to true.
        ::
        ~&  >>  "~initiateAuth"
        ::  state is modified before checks authorisation so think thru if vuln
        ::  I think not b/c default state is unauthorized
        =^  cards  state  (produce-token:main inbound-request)
        =^  cards  state  (subscribe-dms:main inbound-request)
        :_  state
        %+  weld  cards
          %+  give-simple-payload:app:server  id
          %+  require-authorization:app:server  inbound-request
          handle-auth-request:main
      ?>  =(url.request.inbound-request '/~checkAuth')
        ::
        :: Inputs:
        ::   Urbit ship to authenticate @p: String
        ::
        :: Outputs:
        ::   Auth status: Bool
        ::
        :: Side Effects:
        ::   If “authorized status” is true, then set it to false.
        ::
        :: Description:
        ::   Takes @p as an input param and returns the "auth status" value.
        ::   If the value is true, then set it to false. This thus forces
        ::   end user ships to request a fresh auth code on every login/
        ::   authorization request to a website/service, making it more
        ::   secure.
        ::
        ~&  >>  "~checkAuth"
        ::=^  cards  state  (check-dms:main inbound-request)
        ::=^  cards  state  (check-auth:main inbound-request)
        :_  state
        %+  give-simple-payload:app:server  id
        %+  require-authorization:app:server  inbound-request
        ::%+  receive-token
        handle-auth-check:main
    ==
  [cards this]
  ::
  ++  handle-action
    |=  =action:hermes
    ^-  (quip card _state)
    ~&  >>  action
    ?-    -.action
        %http-get
      :_  state
      :~  [%pass /[url.action] %arvo %i %request (get-url url.action) *outbound-config:iris]
      ==
      ::
        %disconnect
      ~&  >>>  "disconnecting at {<bind.action>}"
      :_  state
      [[%pass /bind %arvo %e %disconnect bind.action]]~
      ::
    ==
  ++  get-url
    |=  =url
    ^-  request:http
    [%'GET' url ~ ~]
  --
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  |^
  ?:  ?=(%eyre -.sign-arvo)
    ~&  >>  "Eyre returned: {<+.sign-arvo>}"
    `this
  ?:  ?=(%iris -.sign-arvo)
  ?>  ?=(%http-response +<.sign-arvo)
    =^  cards  state
      (handle-response -.wire client-response.sign-arvo)
    [cards this]
  (on-arvo:default wire sign-arvo)
  ::
  ++  handle-response
    |=  [=url resp=client-response:iris]
    ^-  (quip card _state)
    ~&  >>>  'response-handler:'
    ?.  ?=(%finished -.resp)
      ~&  >>>  -.resp
      `state
    ~&  >>  "got data from {<url>}"
    `state
  --
::
++  on-watch
  |=  =path
  ?:  ?=([%http-response *] path)
    ~&  >>>  "watch request on path: {<path>}"
    `this
  (on-watch:default path)
++  on-leave  on-leave:default
++  on-peek   on-peek:default
++  on-agent
  |=  [=path =sign:agent:gall]
  ^-  (quip card _this)
  ?+    -.sign  (on-agent:default path sign)
      %kick
    ~&  >>  "kicked from subscription {<path>}"
    ~&  >>  "attempting to resubscribe"
    ?~  path  ~|("empty wire, can't resubscribe. this shouldn't happen" `this)
    ?>  ?=([%request-library @ @ ~] path)
    `this
  ::
      %watch-ack
    ?~  p.sign
      ~&  >   "subscribed on wire {<path>} successfully"
      `this
    ~&  >>>  "subscribe on wire {<path>} failed"
    `this
  ::
      %fact
    ::=^  cards  state
      ::?+    p.cage.sign  `state
        ::  %graph-update-2
        =+  !<(=update:graph-store q.cage.sign)
        =/  payload=update:graph-store  !<(update:graph-store q.cage.sign)
        ~&  >  payload
        =/  payload-array  q:+.payload
        ~&  >>  +>.payload-array
        =/  payload-text  +>.payload-array
        ::  Check author of DM
        =/  author  ->->-.payload-text
        ~&  >  author
        ::  Check token of DM
        =/  in-token  ->->+>+<-.payload-text
        ~&  >  in-token
        ::  If they match, then update the authorization
        ::?:  =(((~got by tokens.state) author) in-token)
        ::  =.  status.state  (~(gas by status.state) ~[[target %.n]])
        ::  ~&  >  'it\'s a match!'
        ::  ~[[%give %fact ~[/tokens] [%atom !>(tokens.state)]]]
        ::~[[%give %fact ~[/tokens] [%atom !>(tokens.state)]]]
        ::~&  >  (scry-for:main update:graph-store /graph/(scot %p our.bowl)/dm-inbox)
        ::~&  >  (scry-for:main update:graph-store /keys)
        ::  check if node is resource=[entity=~wes name=%dm-inbox]
        ::=/  payload  q:+>+.sign
        ::~&  >>  +>+<+<+>+>-<+:payload
        ::=/  st  (req-parser-dm payload)
        ::~&  >>>  st
    ::    [cards this]
      ::==
    ::[cards this]
    `this
    ==
++  on-fail   on-fail:default
--
|_  =bowl:gall
++  default-insecure-token  8  ::  8 characters
++  default-token          24  :: 24 characters
++  default-secure-token   64  :: 64 characters
++  max-token-length       86  :: 86 characters from standard entropy as @uwJ
++  generate-token
  |=  len=@ud   :: length in characters
  ^-  tape
  =/  str  (trip (scot %uw `@uw`eny.bowl))
  =/  count  5  :: periodicity of @uw '.'
  =/  index  0
  =/  dots  (flop (fand "." str))
  =/  dot-index  0
  =/  dot-count  (lent dots)
  |-  ^-  tape
  ?:  =(dot-index dot-count)
    (oust [0 (dec (dec (sub (lent str) len)))] (oust [0 2] str))
  $(str (oust [(snag index dots) 1] str), index +(index), dot-index +(dot-index))
++  produce-token
  |=  [req=inbound-request:eyre]
  ^-  (quip card _state)
  =/  payload  (de-json:html `@t`+511:req)
  ?~  payload  !!
  =/  payload-array  u:+.payload
  =/  st  u:+:(req-parser-ot payload-array)
  =/  source  -.st
  =/  target-payload  (de-json:html +.st)
  =/  ship  (req-parser-ship +.target-payload)
  ?~  ship  !!
  =/  target  u:+:`(unit @p)`(slaw %p +.ship)
  =/  token  (generate-token default-token)
  =.  tokens.state  (~(gas by tokens.state) ~[[target token]])
  =.  status.state  (~(gas by status.state) ~[[target %.n]])
  ~&  >>>  (crip "tokens {<tokens.state>}")
  ~&  >>>  (crip "status {<status.state>}")
  :_  state
  :~  [%give %fact ~[/tokens] [%atom !>(tokens.state)]]
      [%give %fact ~[/status] [%atom !>(status.state)]]
  ==
++  subscribe-dms
  |=  [req=inbound-request:eyre]
  ^-  (quip card _state)
  =/  payload  (de-json:html `@t`+511:req)
  ?~  payload  !!
  =/  payload-array  u:+.payload
  =/  st  u:+:(req-parser-ot payload-array)
  =/  source  -.st
  =/  target-payload  (de-json:html +.st)
  =/  ship  (req-parser-ship +.target-payload)
  ?~  ship  !!
  =/  target  u:+:`(unit @p)`(slaw %p +.ship)
  =/  token  (generate-token default-insecure-token)
  ~&  >  "subscribing to dm-inbox"
  :_  state
  ~[[%pass /graph-store %agent [our.bowl %graph-store] %watch /updates]]
  ::[%pass /my/wire %agent [our.bowl agent-name] %leave ~]
:: checkAuth needs to delete token as well as revoke auth
::  .^(noun %gx /=graph-store=/keys/noun)
++  scry-for
  |*  [=mold =path]
  .^  mold
    %gx
    (scot %p our.bowl)
    ::%graph
    %graph-store
    (scot %da now.bowl)
    (snoc `^path`path %noun)
  ==
++  check-dms
  |=  [req=inbound-request:eyre]
  ^-  (quip card _state)
  =/  payload  (de-json:html `@t`+511:req)
  ?~  payload  !!
  =/  payload-array  u:+.payload
  =/  st  u:+:(req-parser-ot payload-array)
  =/  source  -.st
  =/  target-payload  (de-json:html +.st)
  =/  ship  (req-parser-ship +.target-payload)
  ?~  ship  !!
  =/  target  u:+:`(unit @p)`(slaw %p +.ship)
  =/  token  (generate-token default-insecure-token)
  =.  tokens.state  (~(gas by tokens.state) ~[[target token]])
  =.  status.state  (~(gas by status.state) ~[[target %.n]])
  ~&  >>>  (crip "tokens {<tokens.state>}")
  ~&  >>>  (crip "status {<status.state>}")
  :_  state
  :~  [%give %fact ~[/tokens] [%atom !>(tokens.state)]]
      [%give %fact ~[/status] [%atom !>(status.state)]]
  ==

++  send-token
  |=  target=@p
  ^-  (quip card _state)
  :_  state
  ~&  >  "sending to {<target>}"
  ~[[%pass /poke-wire %agent [target %auth] %poke %noun !>([%receive-token (~(get by tokens.state) target)])]]
++  handle-http-request  ::::::::::::::::: DELETEME ::::::::::::::::::::::::::::
  |=  req=inbound-request:eyre
  ^-  simple-payload:http
  =,  enjs:format
  =/  target  ~lex
  =/  auth  (~(gut by status.state) target %.n)
  %-  json-response:gen:server
  %-  pairs
  :~
    [%source [%s (scot %p our.bowl)]]
    [%target [%s (scot %p target)]]
    [%status [%s ?:(%.n 'true' 'false')]]
  ==
++  req-parser-ot
  %-  ot:dejs-soft:format
  :~  [%ship so:dejs-soft:format]
      [%json so:dejs-soft:format]
  ==
++  req-parser-ship
  %-  ot:dejs-soft:format
  :~  [%ship so:dejs-soft:format]
  ==
++  req-parser-dm
  %-  ot:dejs-soft:format
  :~  [%text so:dejs-soft:format]
  ==
++  handle-auth-request
  |=  req=inbound-request:eyre
  ^-  simple-payload:http
  =,  enjs:format
  =/  payload  (de-json:html `@t`+511:req)
  ?~  payload  !!
  =/  payload-array  u:+.payload
  =/  st  u:+:(req-parser-ot payload-array)
  =/  source  -.st
  =/  target-payload  (de-json:html +.st)
  =/  ship  (req-parser-ship +.target-payload)
  ?~  ship  !!
  =/  target  +:`(unit @p)`(slaw %p +.ship)
  =/  auth  (~(gut by status.state) target %.n)
  =/  token  (~(got by tokens.state) target)
  ~&  [%source [%s (scot %p our.bowl)]]
  ~&  [%target [%s (scot %p target)]]
  ~&  [%status [%s ?:(%.n 'true' 'false')]]
  ~&  [%token [%s (crip token)]]
  ::  somewhere in here update/subscribe/etc.
  %-  json-response:gen:server
  %-  pairs
  :~
    [%source [%s (scot %p our.bowl)]]
    [%target [%s (scot %p target)]]
    ::[%status [%s ?:(%.n 'true' 'false')]]
    [%token [%s (crip token)]]
  ==
++  handle-auth-check
  |=  req=inbound-request:eyre
  ^-  simple-payload:http
  =,  enjs:format
  =/  payload  (de-json:html `@t`+511:req)
  ?~  payload  !!
  =/  payload-array  u:+.payload
  =/  st  u:+:(req-parser-ot payload-array)
  =/  source  -.st
  =/  target-payload  (de-json:html +.st)
  =/  ship  (req-parser-ship +.target-payload)
  ?~  ship  !!
  =/  target  +:`(unit @p)`(slaw %p +.ship)
  =/  auth  (~(gut by status.state) target %.n)
  ~&  [%source [%s (scot %p our.bowl)]]
  ~&  [%target [%s (scot %p target)]]
  ~&  [%status [%s ?:(%.n 'true' 'false')]]
  %-  json-response:gen:server
  %-  pairs
  :~
    [%source [%s (scot %p our.bowl)]]
    [%target [%s (scot %p target)]]
    [%status [%s ?:(%.n 'true' 'false')]]
  ==
--
