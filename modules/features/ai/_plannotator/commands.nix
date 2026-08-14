{
  annotate = ''
    ---
    description: Open Plannotator's annotation UI for a file, folder, or URL
    argument-hint: "<path-or-url>"
    ---
    Open Plannotator's annotation UI for this target:

    <target>
    $ARGUMENTS
    </target>

    If no target was provided, ask for one. Otherwise run `plannotator annotate <target>` with Bash and wait for it to finish. Address returned annotations directly. If the session closes without feedback, say so briefly. An approved result may still contain feedback; carry those notes forward as guidance without revising the document over them.
  '';
  last = ''
    ---
    description: Annotate the latest assistant response in Plannotator
    ---
    Do not send a status message before running the command: Plannotator must target the latest rendered assistant response.

    Run `plannotator last` with Bash and wait for it to finish. Incorporate returned feedback into the follow-up response. If the session closes without feedback, mention that briefly. An approved result may still contain feedback; carry those notes forward as guidance without redoing the response over them.
  '';
  review = ''
    ---
    description: Review current changes or a pull request in Plannotator
    argument-hint: "[PR-URL] [--git|--gitbutler]"
    ---
    Open Plannotator's browser-based code review UI by running this command with Bash and waiting for it to finish:

    `plannotator review $ARGUMENTS`

    Address any returned feedback in this conversation. If Plannotator returns an approval or LGTM-style result, acknowledge that the review passed and continue.
  '';
}
