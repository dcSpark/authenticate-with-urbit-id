#   Authenticating with Urbit ID

Urbit provides a platform guaranteeing cryptographically secure identity and authentication.  If a website can demonstrate that a user owns and operates the ship he claims to, then the website can use that fact of authentication as a direct login and additionally use the Urbit ship as a backend data store.  How can a website verify Urbit user identity without having to check the blockchain?  The same way many websites use email to identify a user:  send a unique message to her inbox and check for a match.

![](https://i.pinimg.com/474x/61/b0/fb/61b0fb32a56660b5415bf546c72a8312--mercury-retrograde-greek-pottery.jpg)

The `%authenticate-with-urbit-id` Gall agent plays the role of messenger and guardian, ensuring that any user who requests authorization for a particular ship does in fact control that ship.  Similar to email-based or SMS-based token authentication, `%authenticate-with-urbit-id` utilizes direct messages to demonstrate that a secret token passed to the user is also received from the client ship.

In this tutorial, we will demonstrate how a website can use `%authenticate-with-urbit-id` to authenticate a user, and we will show how the agent itself is constructed.  (The latter assumes some knowledge of Hoon, the Urbit programming language.)


##  Website Authentication

A traditional webserver runs applications which interact with a client-side user's browser on the one hand and a database on the other.  The website must authenticate the client browser session using a password, a token, or a cookie.  Once this has taken place, future interactions are considered secure (modulo a variety of attacks) since the user is “known” to be who he or she claims to be.

Urbit acts as a personal server, complementary to a personal client (or web browser).  Besides its more exotic features, such as an event log, Urbit affords the owner of a “ship” (or unique instance) a persistent database and a cryptographic identity.  Given these facts, a website can use Urbit to both uniquely identify a user and to store user-side data.  `%authenticate-with-urbit-id` facilitates the first of these.

Since Urbit's branding as a “personal server” can create some confusion in terms, we need to define the following elements of website authentication:

1. Website (classically the server-side application).
2. User (classically the client-side application, typically browser-based).
3. Website ship (which runs the `%authenticate-with-urbit-id` agent and authenticates for the website).
4. User ship (which is run by the user and needs to be authenticated).

A website server that wishes to authenticate via `%authenticate-with-urbit-id` needs to run an Urbit ID of its own.  Free transient IDs, called [comets](https://urbit.org/docs/glossary/comet), are available upon startup, but for most purposes a website should prefer to run a stable secure [planet](https://urbit.org/docs/glossary/planet) or [moon](https://urbit.org/docs/glossary/moon).  We assume that you are able to run a planet or moon ship, but reach out if you require assistance in this step.  This is the “website ship.”

Once the website ship is running, the `%authenticate-with-urbit-id` agent should be installed and started.  This exposes two public HTTP endpoints, `/~initiateAuth` and `/~checkAuth`.  (That is, public to the server machine running the ship at `localhost` unless configured as a public-facing server.)

- `/~initiateAuth` accepts a JSON including the unique identity or `@p` of the user ship to be authenticated and returns a JSON including a generated token.  The agent also sets up a subscription to the direct message inbox and watches for the token to be received from the user ship.
- `/~checkAuth` accepts a JSON including the `@p` of the user ship and returns a JSON indicating whether the token has been received from the user ship yet.  If the user ship has authenticated successfully, the agent also clears the status as a security measure.

Using `curl`, one can submit a JSON to the ship and receive a token in reply:

```sh
curl --header "Content-Type: application/json" \
     --request PUT \
     --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
     http://localhost:8080/~initiateAuth
```

With this token, the website should have the user send the token (and only the token text itself) to the website ship.  (This may be done programmatically, as by Urbit Visor, or manually.)

One can also query the status with `curl`:

```sh
curl --header "Content-Type: application/json" \
     --request PUT \
     --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
     http://localhost:8080/~checkAuth
```

Any website can use this method to match a client session to authenticated ownership of an Urbit ship.


##  The `%authenticate-with-urbit-id` Agent

The Urbit hosted operating system consists of the core system loop or event log, surrounded by system services each having a characteristic structure.  System services provide network events, instrument the filesystem, build software, etc.  Gall runs user _agents_, which act like system daemons and play the role of applications.  Every Gall agent has a similar structure which enables the Urbit OS to consistently route events and data between agents.

> If you are interested in understanding how Gall works to instrument Urbit's userspace via agents, we recommend [`~timluc-miptev`'s Gall Guide](https://github.com/timlucmiptev/gall-guide) for a deeper dive.

`%authenticate-with-urbit-id` is a Gall agent.  The source code is available on GitHub at [`dcSpark/authenticate-with-urbit-id`](https://github.com/dcSpark/authenticate-with-urbit-id) under the MIT License.  This section of the tutorial walks through the structure and logic of `%authenticate-with-urbit-id`.

Every Gall agent has ten arms, frequently with a “helper core” providing other necessary operations.

### Starting the Agent

Upon startup, `%authenticate-with-urbit-id` registers the two HTTP endpoints and remains available to handle any requests sent via those paths.  It also initializes the internal state, which consists of a token map (associative array) from ship name `@p` to token `tape` (string) and an authentication map from ship name `@p` to status as a `true`/`false` quantity.

```hoon
++  on-init
  ^-  (quip card _this)
  ~&  >  '%authenticate-with-urbit-id initialized successfully'
  =.  state  [%0 *(map @p tape) *(map @p ?(%.y %.n))]
  :_  this
  :~  [%pass /bind %arvo %e %connect [~ /'~initiateAuth'] %authenticate-with-urbit-id]
      [%pass /bind %arvo %e %connect [~ /'~checkAuth'] %authenticate-with-urbit-id]
  ==
```

The HTTP endpoint registration `%pass`es a message to the `%eyre` server vane connecting each endpoint to `%authenticate-with-urbit-id`.  Any HTTP `PUT` or `GET` requests sent to those endpoints are redirected to this Gall agent.

### Handling Pokes

A poke is a one-time command.  Pokes are responsible to change agent state.  A poke receives a `mark` (or data structure rule) and a `vase` (or value wrapped with its type).  Here, a switch statement ([`?+` wutlus](https://urbit.org/docs/hoon/reference/rune/wut#-wutlus)) defaults to the `on-poke` failure response and otherwise handles only `%handle-http-request` values generated by Eyre from the website or `curl` JSON data.

```hoon
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  =^  cards  state
    ?+    mark  (on-poke:default mark vase)
        %handle-http-request
    :: ... endpoint handlers here ...
    ==
  [cards this]
```

1. If the requested URL matches `/~initiateAuth`, then the state must be modified to produce the tokens, subscribe to the `%dm-inbox` (the direct message path), and only then return the token (from `++handle-auth-request`).

    ```hoon
    ?:  =(url.request.inbound-request '/~initiateAuth')
      ~&  >  "%authenticate-with-urbit-id request hit /~initiateAuth"
      =/  st  (get-source-target:main inbound-request)
      =/  source  -.st
      =/  target  +.st
      =^  cards  state  (produce-token:main source target)
      =^  cards  state  (subscribe-dms:main source target)
      :_  state
      ^-  (list card)
      %+  weld  cards
        %+  give-simple-payload:app:server  id
        (handle-auth-request:main source target)
    ... code in case of other URL ...
    ```

    1. A `card` enables each vane of the Urbit OS to communicate with each other.  It is basically a discrete event consisting of destination and necessary data.  We see a few cards in the `%authenticate-with-urbit-id` code, such as:

        ```hoon
        [%give %fact ~[/tokens] [%atom !>(tokens.state)]]
        [%give %fact ~[/status] [%atom !>(status.state)]]
        ```

        which update the state `tokens` and `status` maps for the requested ship; and

        ```hoon
        [%pass /graph-store %agent [our.bowl %graph-store] %watch /updates]
        ```

        which subscribes to the `%dm-inbox` to check for incoming messages.  Urbit prefers a data-reactive model in which subscriptions are activated and events are only processed when updates are received.

        These are ultimately returned by the standard `++on-XXX` arms of the agent to the Urbit OS, which uses them to update the event log and thereby the system state.

    2. A series of functions at the bottom produces a list of `card`s to be effected on the `state`.  For instance, `++handle-auth-request` is located in the helper core `main`:

        ```hoon
        ++  handle-auth-request
          |=  [source=@p target=@p]
          ^-  simple-payload:http
          =,  enjs:format
          =/  auth  (~(gut by status.state) target %.n)
          =/  token  (~(got by tokens.state) target)
          %-  json-response:gen:server
          %-  pairs
          :~
            [%source [%s (scot %p our.bowl)]]
            [%target [%s (scot %p target)]]
            [%token [%s (crip token)]]
          ==
        ```

        This gate wraps the target ship and the corresponding token in a JSON response which will be emitted after the poke concludes.

        The target ship was obtained from a JSON `PUT` input of the form

        ```json
        {
          "ship":"sampel-palnet",
          "json":"~sampel-talled",
        }
        ```

        (We are intentionally being inconsistent with the tilde `~` here!  We compensate for this below.)

        JSON parsing in Hoon requires two stages:  one step which yields a tagged data structure and another which extracts the particular values of interest.  These take place in the helper arm `++get-source-target`.

        ```hoon
        ++  get-source-target
          |=  [req=inbound-request:eyre]
          ^-  [@p @p]
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
          [source target]
        ```

        1. Here, the parser yields `payload` from `de-json:html`.  This is the entire JSON string itself converted into the Hoon internal JSON representation, which must be processed and checked to make sure that the result isn't `~` (failure to parse).

            ```hoon
            =/  payload  (de-json:html `@t`+511:req)
            ?~  payload  !!
            =/  payload-array  u:+.payload
            ```

            The original JSON

            ```json
            {
              "ship":"sampel-palnet",
              "json":"~sampel-talled"
            }
            ```


            is converted into Hoon representation

            ```hoon
            [ ~
              [ %o
                p={ [
                      p='ship'
                      q=[%s p='sampel-palnet']
                    ]
                    [
                      p='json'
                      q=[%s p='~sampel-talled']
                    ]
                  }
              ]
            ]
            ```

            with type tags on each value indicating the source JSON type.

        2. That resulting data structure is then fed into a reparser, which must be constructed for the particular expected entries:

            ```hoon
            ++  req-parser-ot
              %-  ot:dejs-soft:format
              :~  [%ship so:dejs-soft:format]
                  [%json so:dejs-soft:format]
              ==
            ```

            ```hoon
            =/  st  u:+:(req-parser-ot payload-array)
            ```

            In this case, the only information required by the arm is the user ship `target` and the website ship `source`.  These are extracted from the Airlock-specified JSON structure.

        3. However, the Urbit API is not completely consistent about specifying tildes in front of ship names!  So we check for both possibilities (present and absent) and parse accordingly, using `++slaw` to convert the result text into a `@p` identity.

            ```hoon
            =/  source-t  (trip -.st)
            =/  source
              ?:  =('~' (snag 0 source-t))  u:+:`(unit @p)`(slaw %p (crip source-t))
              u:+:`(unit @p)`(slaw %p (crip (weld "~" source-t)))
            ```

        The output of this gate passes through two other gates which ultimately yield a `list` of `card`s.

2. Back to the big picture:  if the URL request does not match `/~initiateAuth` then it _must_ match `/~checkAuth` (else an assertion error is raised by [`?>` wutgar](https://urbit.org/docs/hoon/reference/rune/wut#-wutgar)).

    ```hoon
    ?>  =(url.request.inbound-request '/~checkAuth')
      ~&  >  "%authenticate-with-urbit-id request hit /~checkAuth"
      =/  st  (get-source-target:main inbound-request)
      =/  source  -.st
      =/  target  +.st
      =/  status  (~(gut by status.state) target %.n)
      ~&  >  status
      =^  cards  state  (clear-auth:main source target)
      :_  state
      %+  weld  cards
        %+  give-simple-payload:app:server  id
        (handle-auth-check:main source target status)
    ```

    1. As before, we have two chains of events which need to resolve in order.  We need to check the state and then clear it if it has been set.  We also need to return the status of the check.  First, the state must be checked and the reply JSON formed:

        ```hoon
        ++  handle-auth-check
          |=  [source=@p target=@p status=?(%.y %.n)]
          ^-  simple-payload:http
          =,  enjs:format
          %-  json-response:gen:server
          %-  pairs
          :~
            [%source [%s (scot %p our.bowl)]]
            [%target [%s (scot %p target)]]
            [%status [%s ?:(status 'true' 'false')]]
          ==
        ```

    2. The token must then be cleared in sequence if it is active.  (Notably, the relative isolation of Gall agent arms from each other here makes it necessary to extricate the information more than once from the active request.)

        ```hoon
        ++  clear-auth
          |=  [source=@p target=@p]
          ^-  (quip card _state)
          =/  auth-status  (~(gut by status.state) target %.n)
          ::  only clear the tokens if the status is %.y, else it's too soon
          =.  tokens.state  ?:(auth-status (~(del by tokens.state) target) tokens.state)
          =.  status.state  ?:(auth-status (~(del by status.state) target) status.state)
          :_  state
          :~  [%give %fact ~[/tokens] [%atom !>(tokens.state)]]
              [%give %fact ~[/status] [%atom !>(status.state)]]
          ==
        ```

`%authenticate-with-urbit-id` is a straightforward agent which demonstrates internal state updates, API endpoint exposure, `graph-store` subscriptions, and card structure and order.

Since every DM is examined for content, it is recommended that this agent run on a designated ship (such as a moon), rather than on a ship used for social purposes.

> At this point, it is worth considering how one would construct an agent that can receive more than one fact from the input.
>
> - One can wrap the JSON in the `json` entry of the request JSON.  This may require escaping internal JSON elements and gets messy to construct.
>
>     ```json
>     '{"ship":"sampel-talled","json":"sampel-palnet"}' \
>     ```
>
> - One can pass in more arguments to the request JSON.
>
>     ```json
>     '{"ship":"sampel-talled","json":"sampel-palnet","foo":"bar"}'
>     ```
>
> In either case, additional reparsing will need to be written for each step.
