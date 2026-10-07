# artifact-registry

Cria um repositório do Artifact Registry para guardar as imagens de container
usadas no deploy do Cloud Run.

## Uso

```hcl
module "registry" {
  source     = "../../modules/artifact-registry"
  project_id = "seu-projeto-id"

  # repository_id default já é "cloud-run-source-deploy"
}

output "repository_url" {
  value = module.registry.repository_url
}
```

`repository_url` sai pronto para compor a tag da imagem, ex:
`us-central1-docker.pkg.dev/seu-projeto-id/cloud-run-source-deploy/app:latest`.
