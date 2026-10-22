# Projeto geapp-prod (GCP `geapp-gentrop-prod-0001`)

Uma pasta por projeto/ambiente: cada uma tem o proprio `project_id` (em `main.tf`)
e o proprio state remoto (`prefix` em `versions.tf`). Para um novo projeto/ambiente/stack, copie
esta pasta para `projects/<projeto>/<ambiente>/<stack>`, troque `project_id`, `prefix`
e rode `terraform init`.

Regra: nunca troque o `project_id` de uma pasta ja aplicada -- crie outra pasta.

## Bucket de state (uma vez, fora do Terraform)

```bash
gcloud storage buckets create gs://gentrop-tfstate --project=geapp-gentrop-prod-0001 --location=us-central1 --uniform-bucket-level-access
gcloud storage buckets update gs://gentrop-tfstate --versioning
```

## Migrar o state local existente (de samples/artifact-registry-secret-manager-cloud-run)

```bash
cp ../../../../samples/artifact-registry-secret-manager-cloud-run/terraform.tfstate .
terraform init -migrate-state   # responda yes
terraform plan                  # deve dar "No changes"
```

Depois apague o `terraform.tfstate` local desta pasta e nao rode mais apply no sample.
