import { Form, Head } from "@inertiajs/react"

<% if use_teams %>
import TeamInvitationAlert from "@/components/team-invitation-alert"
<% end %>
import TextLink from "@/components/text-link"
import { Button } from "@/components/ui/button"
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { Spinner } from "@/components/ui/spinner"
import AuthLayout from "@/layouts/auth-layout"
import { identityPasswordResets, sessions, users } from "@/routes"
<% if use_teams %>
import type { SessionsNew } from "@/types"

export default function Login({ team_invitation }: SessionsNew) {
<% else %>

export default function Login() {
<% end %>
  return (
    <AuthLayout
      title="Log in to your account"
      description="Enter your email and password below to log in"
    >
      <Head title="Log in" />
<% if use_teams %>

      {team_invitation && (
        <TeamInvitationAlert invitation={team_invitation} action="Log in" />
      )}

<% end %>
      <Form
        action={sessions.create()}
        resetOnSuccess={["password"]}
        className="flex flex-col gap-6"
      >
        {({ processing, errors }) => (
          <>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="email">Email address</FieldLabel>
                <Input
                  id="email"
                  name="email"
                  type="email"
                  required
                  autoFocus
                  tabIndex={1}
                  autoComplete="email"
                  placeholder="email@example.com"
                />
                <FieldError
                  errors={errors.email?.map((message) => ({ message }))}
                />
              </Field>

              <Field>
                <div className="flex items-center">
                  <FieldLabel htmlFor="password">Password</FieldLabel>
                  <TextLink
                    href={identityPasswordResets.new()}
                    className="ml-auto text-sm"
                    tabIndex={5}
                  >
                    Forgot password?
                  </TextLink>
                </div>
                <Input
                  id="password"
                  type="password"
                  name="password"
                  required
                  tabIndex={2}
                  autoComplete="current-password"
                  placeholder="Password"
                />
                <FieldError
                  errors={errors.password?.map((message) => ({ message }))}
                />
              </Field>

              <Button
                type="submit"
                className="mt-4 w-full"
                tabIndex={4}
                disabled={processing}
              >
                {processing && <Spinner />}
                Log in
              </Button>
            </FieldGroup>

            <div className="text-muted-foreground text-center text-sm">
              Don&apos;t have an account?{" "}
              <TextLink href={<%= use_teams ? "users.new({ query: { invitation: team_invitation?.code } })" : "users.new()" %>} tabIndex={5}>
                Sign up
              </TextLink>
            </div>
          </>
        )}
      </Form>
    </AuthLayout>
  )
}
