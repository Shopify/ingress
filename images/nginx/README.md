
nginx 1.15.x base image using [debian-base](https://github.com/kubernetes/kubernetes/tree/master/build/debian-base)

nginx [engine x] is an HTTP and reverse proxy server, a mail proxy server, and a generic TCP proxy server.

This custom nginx image contains:

- [stream](http://nginx.org/en/docs/stream/ngx_stream_core_module.html) tcp support for upstreams
- [Dynamic TLS record sizing](https://blog.cloudflare.com/optimizing-tls-over-tcp-to-reduce-latency/)
- [ngx_devel_kit](https://github.com/simpl/ngx_devel_kit)

**How to use this image:**
This image provides a default configuration file with no backend servers.

*Using docker*

```console
docker run -v /some/nginx.con:/etc/nginx/nginx.conf:ro quay.io/kubernetes-ingress-controller/nginx:0.56
```

*Creating a replication controller*

```console
kubectl create -f ./rc.yaml
```
