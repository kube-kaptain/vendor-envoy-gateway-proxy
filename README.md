# Vendor Envoy Gateway Proxy

Provides a preconfigured Envoy Gateway proxy instance with reasonable defaults
that can be overridden and minimal required configuration. The upstream envoy
image is also retagged to isolate from upstream mistakes or compromises.

This complements [`vendor-envoy-gateway`](../vendor-envoy-gateway), which ships
the Envoy Gateway controller and supporting resources.


## Upstream Image

- Project: https://gateway.envoyproxy.io/
- Image: `docker.io/envoyproxy/envoy`
- Tag tracked in: `KaptainPM.yaml` under `spec.main.docker.retag.sourceTag`

The version matches the internal one used by the Envoy Gateway controller release
in use. Envoy Gateway code hard-codes a version of the envoy image in its source.
The value of `DefaultEnvoyProxyImage` in `api/v1alpha1/shared_types.go` provides
us with the tag we need to use. When updating this project, check that file for
the tag used in the other matching projects.


## Manifests

### `src/kubernetes/gateway.yaml`

A Gateway API `Gateway` resource. This is the top-level entry point for inbound
traffic: it declares the listener (protocol, port, TLS certificate, allowed-routes
namespaces) and binds to a `GatewayClass`. Its `infrastructure.parametersRef`
points at the `EnvoyProxy` below, telling Envoy Gateway how to provision the
data-plane deployment and service for this specific gateway.

### `src/kubernetes/envoyproxy.yaml`

An `EnvoyProxy` resource (Envoy Gateway CRD). This configures the data-plane
deployment and service that Envoy Gateway provisions on behalf of the `Gateway`
above: replicas, rolling-update strategy, resource requests and limits,
container security context, pod anti-affinity across nodes and zones,
graceful-shutdown timings, JSON access logging to stdout, Prometheus
metrics, and log level. The `container.image` field is where the
retagged image produced by this repo is referenced.


## Version Verification

A hook script is present to pull down the source code from envoy gateway by tag
and check that the versions and other fields present and in use in the project
actually match the tagged source of the upstream project where the image is hard
coded.


## Structure

- `KaptainPM.yaml` - pipeline configuration, including the upstream image to retag
- `src/upstream/version` - for tagging and for coherency testing in the build
- `src/kubernetes/` - Gateway and EnvoyProxy manifests with token placeholders
- `src/defaults/` - default values prefixed with `VendorEnvoyGatewayProxy/` for tokens
- `.github/workflows/build.yaml` - GH workflow reference, permissions, and triggers
