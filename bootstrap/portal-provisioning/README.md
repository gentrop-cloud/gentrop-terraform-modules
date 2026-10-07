# Bootstrap do provisionamento via portal

Roda **uma vez**, à mão, por alguém com Owner no projeto de controle
(`geapp-gentrop-prod-0001`) e nos projetos de clientes listados em
`client_project_ids`. Cria:

- **WIF** `github-terraform` / `terraform-modules`: só o `provision.yml` da `main`
  deste repositório consegue trocar o token do GitHub por credencial GCP.
- **SA `tf-provisioner`**: escreve no bucket `gentrop-tfstate` e tem, em cada
  projeto de cliente, os papéis que os stacks de `stacks/` exigem.
- **Secret Manager para o portal**: quando `portal_service_account_email` é
  informado, a SA do portal ganha `secretmanager.admin` nos projetos de clientes.

## Aplicar

```bash
gcloud auth application-default login
terraform init
terraform apply
```

Depois, configure as variáveis do repositório com os outputs:

```bash
gh variable set WIF_PROVIDER    --repo gentrop-cloud/gentrop-terraform-modules --body "$(terraform output -raw workload_identity_provider)"
gh variable set TF_SA_EMAIL     --repo gentrop-cloud/gentrop-terraform-modules --body "$(terraform output -raw service_account_email)"
gh variable set TF_STATE_BUCKET --repo gentrop-cloud/gentrop-terraform-modules --body "gentrop-tfstate"
gh variable set PORTAL_URL      --repo gentrop-cloud/gentrop-terraform-modules --body "https://<url pública do portal>"
```

## Onboarding de um cliente novo

Adicione o projeto em `client_project_ids` e rode `terraform apply` de novo.
Sem isso, o `provision.yml` falha com `PERMISSION_DENIED` no projeto do cliente.
