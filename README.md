# Authenticate With Urbit ID

This is a Gall agent which enables third-party servers and service providers outside of Urbit to authenticate users, thereby providing a “Login with Urbit ID” experience to classical websites.  `%hermes` affords a website running a backend ship to authenticate that a website user does in fact control a particular Urbit ship.  The principle is similar to email token-based authentication.

When paired with Urbit Visor, this applications allows users to authenticate themselves on any classical web2 site by simply accepting permissions.

##  API

`%hermes` exposes the following endpoints:

- `/~initiateAuth` (not secure)
  - Input:  An Airlock-standard JSON containing the user ship `ship` as a string.
  - Output:  An Airlock-standard JSON containing the website ship `source` as a string, the user ship `ship` as a string, and the token for the user as a string.
  - Example:

      ```sh
      curl --header "Content-Type: application/json" \
           --request PUT \
           --data '{"ship":"zod","action":"poke","app":"hermes","json":"{\"ship\":\"~nec\"}","mark":"noun"}' \
           http://localhost:8080/~initiateAuth
      ```

- `/~checkAuth` (not secure)
  - Input:  A JSON containing the user ship `ship` as a string.
  - Output:  A JSON containing the requesting website ship `source` as a string, the user ship `target` as a string, and the status of the user ship `status` as a string.
  - Example:

      ```sh
      curl --header "Content-Type: application/json" \
           --request PUT \
           --data '{"ship":"zod","action":"poke","app":"hermes","json":"{\"ship\":\"~nec\"}","mark":"noun"}' \
           http://localhost:8080/~checkAuth
      ```

In between the website hitting each endpoint, the user's ship should emit a DM containing the secure token to the website ship.  `%hermes` has subscribed to the `%dm-inbox` and will update the authorization status to `true` as soon as a DM containing the token has been received.

In the case of multiple initiations, earlier tokens are instantly invalidated.

As soon as a successful check has been made, `%hermes` clears the authorization status of the user ship.


##  Example Workflow

_This example assumes that the developer is a running a “website ship” `~zod` and a “user ship” `~nec`._

1. Start `%hermes` on website ship `~zod`.
2. Request a token from website ship `~zod` for user ship `~nec`.

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"zod","action":"poke","app":"hermes","json":"{\"ship\":\"~nec\"}","mark":"noun"}' \
         http://localhost:8080/~initiateAuth
    ```

3. Check the authentication status of `~nec` from `~zod` and confirm that the user ship is not authorized yet.

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"zod","action":"poke","app":"hermes","json":"{\"ship\":\"~nec\"}","mark":"noun"}' \
         http://localhost:8080/~checkAuth
    ```

3. Emit a DM from `~nec` to `~zod` at the Dojo prompt.  (This should contain the token returned in the first step.)

    ```sh
    :dm-hook|dm ~zod ~[[%text 'RENV~jjr1W-ICCIlBr9ZVIxg']]
    ```

4. Check the authentication status of `~nec` from `~zod` and confirm that the user ship has been authorized.

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"zod","action":"poke","app":"hermes","json":"{\"ship\":\"~nec\"}","mark":"noun"}' \
         http://localhost:8080/~checkAuth
    ```

5. Check the authentication status of `~nec` from `~zod` and confirm that the user ship is once again not authorized.

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"zod","action":"poke","app":"hermes","json":"{\"ship\":\"~nec\"}","mark":"noun"}' \
         http://localhost:8080/~checkAuth
    ```

##  Issues

- DMs on fakezods seem to be laggy which can make testing difficult.
