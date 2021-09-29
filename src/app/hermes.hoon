  ::
::::  hermes.hoon
::
::      %gall agent to authenticate a ship for Urbit Visor.
::
::    The basic architecture is that Visor requests a website running the agent
::    to produce a token and wait for a DM containing the token from the
::    authenticating ship.
::
/-  graph-store
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
+$  url     @t
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
+*  this      .
    default   ~(. (default-agent this %|) bowl)
    main      ~(. +> bowl)
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
    ~&  >  '%hermes version %0'
    `this(state prev)
  ==
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  =^  cards  state
    ?+    mark  (on-poke:default mark vase)
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
        ~&  >  "%hermes request hit /~initiateAuth"
        =^  cards  state  (produce-token:main inbound-request)
        =^  cards  state  (subscribe-dms:main inbound-request)
        :_  state
        ^-  (list card)
        %+  weld  cards
          %+  give-simple-payload:app:server  id
          %+  skip-authorization:main  inbound-request
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
        ~&  >  "%hermes request hit /~checkAuth"
        :_  state
        ^-  (list card)
        %+  weld
          %+  give-simple-payload:app:server  id
          %+  skip-authorization:main  inbound-request
          handle-auth-check:main
        (clear-auth:main inbound-request)
    ==
  [cards this]
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
  =^  cards  state
  ?-    -.sign  ::[- state]:(on-agent:default path sign)
      %poke-ack
    [- state]:(on-agent:default path sign)
  ::
      %watch-ack
    ?~  p.sign
      ~&  >   "subscribed on wire {<path>} successfully"
      [- state]:(on-agent:default path sign)
    ~&  >>>  "subscribe on wire {<path>} failed"
    [- state]:(on-agent:default path sign)
  ::
      %kick
    ~&  >>  "kicked from subscription {<path>}"
    ~&  >>  "attempting to resubscribe"
    ?~  path
      ~|  "empty wire, can't resubscribe. this shouldn't happen"
      [- state]:(on-agent:default path sign)
    ?>  ?=([%request-library @ @ ~] path)
    :_  state
      ~[[%pass /graph-store %agent [our.bowl %graph-store] %watch /updates]]
  ::
      %fact
    ?+    p.cage.sign  ~|([dap.bowl %bad-sub-mark wire p.cage.sign] !!)
        %graph-update-2
      ^-  (quip card _state)
      =+  !<(=update:graph-store q.cage.sign)
      =/  payload=update:graph-store  !<(update:graph-store q.cage.sign)
      ::  Is this a DM?  If not, bail.
      =/  is-dm  =(+>->:payload %dm-inbox)
      ?.  is-dm
        ~&  >>  "%hermes:  not a DM"
        [- state]:(on-agent:default path sign)
      =/  payload-array  q:+.payload
      =/  payload-text  +>.payload-array
      ::  Check author of DM
      =/  author  ->->-.payload-text
      ?>  ?=(@p author)  :: resolve fork in resolution
      ::  Has this token been requested?  If not, bail.
      =/  is-requested  %.y
      ?.  is-requested
        ~&  >>  "%hermes:  ship not requested"
        [- state]:(on-agent:default path sign)
      ::  Check token of DM
      ~&  >  "%hermes:  attempting to extract token from DM"
      =/  trial-token-payload  ->->+>+<-.payload-text
      ?>  ?=([%text @t] trial-token-payload)
      =/  trial-token  `@t`text:+.trial-token-payload
      ?.  =((crip (~(gut by tokens.state) author ~)) trial-token)
        ~&  >>>  "%hermes:  incorrect token for {<author>}"
        [~[[%give %fact ~[/status] [%atom !>(status.state)]]] state]
      =.  status.state  (~(gas by status.state) ~[[author %.y]])
      ~&  >  "%hermes:  status for {<author>} confirmed"
      :_  state
      ~[[%give %fact ~[/status] [%atom !>(status.state)]]]
    ==
  ==
  [cards this]
++  on-fail   on-fail:default
--
|_  =bowl:gall
++  default-insecure-token     8  ::  8 characters
++  default-token             24  :: 24 characters
++  default-secure-token      64  :: 64 characters
++  max-token-length          86  :: 86 characters from standard entropy as @uwJ
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
  =/  source-t  (trip -.st)
  =/  source
    ?:  =('~' (snag 0 source-t))  u:+:`(unit @p)`(slaw %p (crip source-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" source-t)))
  =/  target-t  (trip +.st)
  =/  target
    ?:  =('~' (snag 0 target-t))  u:+:`(unit @p)`(slaw %p (crip target-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" target-t)))
  =/  token  (generate-token default-token)
  =.  tokens.state  (~(gas by tokens.state) ~[[target token]])
  =.  status.state  (~(gas by status.state) ~[[target %.n]])
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
  =/  source-t  (trip -.st)
  =/  source
    ?:  =('~' (snag 0 source-t))  u:+:`(unit @p)`(slaw %p (crip source-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" source-t)))
  =/  target-t  (trip +.st)
  =/  target
    ?:  =('~' (snag 0 target-t))  u:+:`(unit @p)`(slaw %p (crip target-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" target-t)))
  =/  token  (generate-token default-insecure-token)
  :_  state
  ~[[%pass /graph-store %agent [our.bowl %graph-store] %watch /updates]]
++  clear-auth
  |=  [req=inbound-request:eyre]
  ::^-  (quip card _state)
  ^-  (list card)
  =/  payload  (de-json:html `@t`+511:req)
  ?~  payload  !!
  =/  payload-array  u:+.payload
  =/  st  u:+:(req-parser-ot payload-array)
  =/  source-t  (trip -.st)
  =/  source
    ?:  =('~' (snag 0 source-t))  u:+:`(unit @p)`(slaw %p (crip source-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" source-t)))
  =/  target-t  (trip +.st)
  =/  target
    ?:  =('~' (snag 0 target-t))  u:+:`(unit @p)`(slaw %p (crip target-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" target-t)))
  =/  auth-status  (~(gut by status.state) target %.n)
  ::  only clear the tokens if the status is %.y, else it's too soon
  =.  tokens.state  ?:(auth-status (~(del by tokens.state) target) tokens.state)
  =.  status.state  ?:(auth-status (~(del by status.state) target) status.state)
  :::_  state
  :~  [%give %fact ~[/tokens] [%atom !>(tokens.state)]]
      [%give %fact ~[/status] [%atom !>(status.state)]]
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
++  handle-auth-request
  |=  req=inbound-request:eyre
  ^-  simple-payload:http
  =,  enjs:format
  =/  payload  (de-json:html `@t`+511:req)
  ?~  payload  !!
  =/  payload-array  u:+.payload
  =/  st  u:+:(req-parser-ot payload-array)
  =/  source-t  (trip -.st)
  =/  source
    ?:  =('~' (snag 0 source-t))  u:+:`(unit @p)`(slaw %p (crip source-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" source-t)))
  =/  target-t  (trip +.st)
  =/  target
    ?:  =('~' (snag 0 target-t))  u:+:`(unit @p)`(slaw %p (crip target-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" target-t)))
  =/  auth  (~(gut by status.state) target %.n)
  =/  token  (~(got by tokens.state) target)
  %-  json-response:gen:server
  %-  pairs
  :~
    [%source [%s (scot %p our.bowl)]]
    [%target [%s (scot %p target)]]
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
  =/  source-t  (trip -.st)
  =/  source
    ?:  =('~' (snag 0 source-t))  u:+:`(unit @p)`(slaw %p (crip source-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" source-t)))
  =/  target-t  (trip +.st)
  =/  target
    ?:  =('~' (snag 0 target-t))  u:+:`(unit @p)`(slaw %p (crip target-t))
    u:+:`(unit @p)`(slaw %p (crip (weld "~" target-t)))
  =/  auth-status  (~(gut by status.state) target %.n)
  ~&  [%source [%s (scot %p our.bowl)]]
  ~&  [%target [%s (scot %p target)]]
  ~&  [%status [%s ?:(auth-status 'true' 'false')]]
  %-  json-response:gen:server
  %-  pairs
  :~
    [%source [%s (scot %p our.bowl)]]
    [%target [%s (scot %p target)]]
    [%status [%s ?:(auth-status 'true' 'false')]]
  ==
++  skip-authorization
  |=  $:  =inbound-request:eyre
          handler=$-(inbound-request:eyre simple-payload:http)
      ==
  ^-  simple-payload:http
  ~!  this
  ~!  +:*handler
  (handler inbound-request)
--

