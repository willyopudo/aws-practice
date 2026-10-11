# __LAB_NAME__

## Goal

<!-- One sentence. What should I be able to do after this that I couldn't before? -->

## What it builds

<!-- A short list of the resources and how they connect. -->

## Cost

<!-- Free tier? Or $X/hr while it's up? Fill this in BEFORE you apply. -->

## Run it

```bash
../../scripts/whoami.sh          # confirm the right account
cd terraform
terraform init
terraform plan
terraform apply
```

## Tear it down

```bash
cd terraform
terraform destroy
cd ../../.. && ./scripts/sweep.sh   # confirm nothing lingers
```

## What I learned

<!-- Fill in after. Gotchas, surprises, things the docs got wrong.
     Anything reusable belongs in ../../notes/<service>.md instead. -->
