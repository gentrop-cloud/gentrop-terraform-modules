# hyper-agent no projeto `geapp-gentrop-prod-0001`

Mesma stack de `examples/hyper-agent`, mas com `project_id` do geapp e state
remoto proprio (`prefix = clientes/geapp-prod-hyper-agent`), separado de
`clientes/geapp/prod/app`. Veja o README de `examples/hyper-agent` para detalhes da stack.

## Antes do primeiro apply

1. Bucket `gentrop-tfstate` criado (ver `clientes/geapp/prod/app/README.md`).
2. `terraform init` -- state novo e vazio; NAO copie o state de `examples/hyper-agent`
   (ele e do projeto `estudos-jean-pereira`).
3. SMTP real: `terraform.tfvars` com `smtp_password = "..."` (ignorado pelo git).
4. `terraform plan` e confira: so deve haver `add`, nenhum `destroy`/`replace`.
