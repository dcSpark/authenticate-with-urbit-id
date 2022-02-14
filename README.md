# Authenticate With Urbit ID

A Gall agent which enables webservers and service providers outside of Urbit to authenticate users, thereby providing a “Login with Urbit ID” experience. `%authenticate-with-urbit-id` affords a website running a backend ship to authenticate that a website user does in fact control a particular Urbit ship (thereby supporting hosted ships, L2 ships, and other potential edge cases as well). The authentication protocol is similar to email token-based authentication schemes.

When paired with Urbit Visor, this application will allows users to easily authenticate themselves on classical web2 sites which integrate Authenticate With Urbit ID. 

Do note, the website/backend ship running `%authenticate-with-urbit-id` must be trusted (meaning run by the website provider, or a trusted 3rd party) and secured on a server with a strong firewall which only allows the website backend (ip) to interact with it. This was chosen to simplify the setup process and reuse the existing networking tech stack so that integration would be easier for implementors with little knowledge of Urbit.

Check out [the announcement youtube video](https://www.youtube.com/watch?v=M0j7maBfRmA) for an easy-to-follow summary of Authenticate With Urbit ID.
After the youtube video, [this deep-dive medium post](https://medium.com/dcspark/authenticate-website-users-using-urbit-id-e6dc8c4cb4fa) is recommended as well.

##  Installation

### From Repo (As Host)

1. Boot the host ship.
2. On that ship, `|merge %authenticate-with-urbit-id our %base`.
3. On that ship, `|mount %authenticate-with-urbit-id`.
4. Outside the ship, `rm -rf ship/authenticate-with-urbit-id/*`.
5. Outside the ship, `cp -r git-repo/src/* ship/authenticate-with-urbit-id`.
6. Inside the ship, `|commit %authenticate-with-urbit-id`.
7. Inside the ship, `|install our %authenticate-with-urbit-id`.  You should see a success message and a %no-docket-file-for warning.
8. Inside the ship, `|public %authenticate-with-urbit-id` (note that this is different because there is no docket file or tile).
9. From another ship, install at the command line:  `|install ~sampel-palnet %authenticate-with-urbit-id` (without a docket file, which we don't need, it currently won't show at the GUI).

##  API

`%authenticate-with-urbit-id` exposes the following endpoints:

- `/~initiateAuth`
  - Input:  An Airlock-standard JSON containing the user ship `ship` as a string.
  - Output:  An Airlock-standard JSON containing the website ship `source` as a string, the user ship `ship` as a string, and the token for the user as a string.
  - Example:

      ```sh
      curl --header "Content-Type: application/json" \
           --request PUT \
           --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
           http://localhost:8080/~initiateAuth
      ```

- `/~checkAuth`
  - Input:  A JSON containing the user ship `ship` as a string.
  - Output:  A JSON containing the requesting website ship `source` as a string, the user ship `target` as a string, and the status of the user ship `status` as a string.
  - Example:

      ```sh
      curl --header "Content-Type: application/json" \
           --request PUT \
           --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
           http://localhost:8080/~checkAuth
      ```

In between the website hitting each endpoint, the user's ship should emit a DM containing the secure token to the website ship.  `%authenticate-with-urbit-id` has subscribed to the `%dm-inbox` and will update the authorization status to `true` as soon as a DM containing the token has been received.

In the case of multiple initiations, earlier tokens are instantly invalidated.

As soon as a successful check has been made, `%authenticate-with-urbit-id` clears the authorization status of the user ship.


##  Example Workflow

_This example assumes that the developer is a running a “website ship” `~sampel-talled` and a “user ship” `~sampel-palnet`.  (Do note: DMs do not work particularly well between fakezod galaxies.)_

1. Start `%authenticate-with-urbit-id` on website ship `~sampel-talled`.
2. Make a request to `%authenticate-with-urbit-id` on `~sampel-talled` to generate a token (typically done via the website backend) for user ship `~sampel-palnet` (this token is then returned to the end user from the backend to the frontend, and would be fed through Urbit Visor's API in a DM, as is specified in step 4).

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
         http://localhost:8080/~initiateAuth
    ```

3. Check the authentication status of `~sampel-palnet` and confirm that the user ship is not authorized yet.

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
         http://localhost:8080/~checkAuth
    ```

4. Send a DM from `~sampel-palnet` to `~sampel-talled` at which contains the token returned in the first step (this is the authentication step, which in our text workflow is send a dm via dojo, however typically would be done via Urbit Visor).

    ```sh
    :dm-hook|dm ~sampel-talled ~[[%text 'RENV~jjr1W-ICCIlBr9ZVIxg']]
    ```

5. Check the authentication status of `~sampel-palnet` from `~sampel-talled` and confirm that the user ship has been authorized.

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
         http://localhost:8080/~checkAuth
    ```

6. Reheck the authentication status of `~sampel-palnet` from `~sampel-talled` and confirm that the user ship is once again not authorized (`/~checkAuth` is a one-time consume check, meaning that users must reauthorize themselves every time they want to login.)

    ```sh
    curl --header "Content-Type: application/json" \
         --request PUT \
         --data '{"ship":"sampel-talled","json":"sampel-palnet"}' \
         http://localhost:8080/~checkAuth
    ```
