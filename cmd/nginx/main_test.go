/*
Copyright 2017 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"fmt"
	"os"
	"strings"
	"syscall"
	"testing"
	"time"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/fake"

	"k8s.io/ingress-nginx/internal/file"
	"k8s.io/ingress-nginx/internal/ingress/controller"
	"k8s.io/ingress-nginx/internal/nginx"
)

const PodName = "testpod"
const ConfigName = "config"
const PodNamespace = "ns"

func assertConfContains(s string, t *testing.T) {
	conf, err := nginx.ReadNginxConf()
	if err != nil {
		t.Fatalf("error reading nginx.conf: %v", err)
	}

	t.Logf("%v", conf)

	if !strings.Contains(conf, s) {
		t.Fatalf("nginx.conf does not contain %v", s)
	}
}

func createFakeController(clientSet *fake.Clientset, t *testing.T) *controller.NGINXController {
	pod := v1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      PodName,
			Namespace: PodNamespace,
		},
	}

	_, err := clientSet.CoreV1().Pods(PodNamespace).Create(&pod)
	if err != nil {
		t.Fatalf("error creating pod %v: %v", pod, err)
	}

	resetForTesting(func() { t.Fatal("bad parse") })

	os.Setenv("POD_NAME", PodName)
	os.Setenv("POD_NAMESPACE", PodNamespace)
	defer os.Setenv("POD_NAME", "")
	defer os.Setenv("POD_NAMESPACE", "")

	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"cmd", "--default-backend-service", "ingress-nginx/default-backend-http", "--http-port", "0", "--https-port", "0", "--configmap", PodNamespace + "/" + ConfigName}
	t.Logf("%v", os.Args)
	_, conf, err := parseFlags()
	if err != nil {
		t.Errorf("Unexpected error creating NGINX controller: %v", err)
	}
	conf.Client = clientSet

	fs, err := file.NewFakeFS()
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	return controller.NewNGINXController(conf, nil, fs)
}

func cleanupPod(clientSet *fake.Clientset, t *testing.T) {
	err := clientSet.CoreV1().Pods(PodNamespace).Delete(PodName, &metav1.DeleteOptions{})
	if err != nil {
		t.Fatalf("error deleting pod %v: %v", PodName, err)
	}
}

func TestUseGeoIP2(t *testing.T) {
	clientSet := fake.NewSimpleClientset()
	createConfigMap(clientSet, ConfigName, PodNamespace, map[string]string{
		"use-geoip2": "true",
	}, t)
	defer deleteConfigMap(ConfigName, PodNamespace, clientSet, t)

	_ = createFakeController(clientSet, t)
	defer cleanupPod(clientSet, t)

	time.Sleep(10 * time.Second)

	assertConfContains("/etc/nginx/modules/ngx_http_geoip2_module.so", t)
}

func TestCreateApiserverClient(t *testing.T) {
	_, err := createApiserverClient("", "")
	if err == nil {
		t.Fatal("Expected an error creating REST client without an API server URL or kubeconfig file.")
	}
}

func TestHandleSigterm(t *testing.T) {
	clientSet := fake.NewSimpleClientset()
	createConfigMap(clientSet, ConfigName, PodNamespace, map[string]string{}, t)
	defer deleteConfigMap(ConfigName, PodNamespace, clientSet, t)

	ngx := createFakeController(clientSet, t)
	defer cleanupPod(clientSet, t)

	go handleSigterm(ngx, func(code int) {
		if code != 1 {
			t.Errorf("Expected exit code 1 but %d received", code)
		}

		return
	})

	time.Sleep(1 * time.Second)

	t.Logf("Sending SIGTERM to PID %d", syscall.Getpid())
	err := syscall.Kill(syscall.Getpid(), syscall.SIGTERM)
	if err != nil {
		t.Error("Unexpected error sending SIGTERM signal.")
	}
}

func createConfigMap(clientSet *fake.Clientset, name string, ns string, data map[string]string, t *testing.T) {
	t.Helper()
	t.Log("Creating temporal config map")

	configMap := &v1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:     name,
			SelfLink: fmt.Sprintf("/api/v1/namespaces/%s/configmaps/config", ns),
		},
		Data: data,
	}

	cm, err := clientSet.CoreV1().ConfigMaps(ns).Create(configMap)
	if err != nil {
		t.Errorf("error creating the configuration map: %v", err)
	}
	t.Logf("Temporal configmap %v created", cm)
}

func deleteConfigMap(name, ns string, clientSet *fake.Clientset, t *testing.T) {
	t.Helper()
	t.Logf("Deleting temporal configmap %v", name)

	err := clientSet.CoreV1().ConfigMaps(ns).Delete(name, &metav1.DeleteOptions{})
	if err != nil {
		t.Errorf("error deleting the configmap: %v", err)
	}
	t.Logf("Temporal configmap %v deleted", name)
}
