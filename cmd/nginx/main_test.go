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
	"os"
	"strings"
	"syscall"
	"testing"
	"time"

	v1 "k8s.io/api/core/v1"
	"k8s.io/api/extensions/v1beta1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/client-go/kubernetes/fake"

	"k8s.io/ingress-nginx/internal/file"
	"k8s.io/ingress-nginx/internal/ingress/controller"
	"k8s.io/ingress-nginx/internal/ingress/metric"
)

const PodName = "testpod"
const PodNamespace = "ns"

type configTest struct {
	t         *testing.T
	clientSet *fake.Clientset
	args      []string
}

func (ct *configTest) GetController() *controller.NGINXController {
	if ct.clientSet == nil {
		ct.clientSet = fake.NewSimpleClientset()
	}

	pod := v1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      PodName,
			Namespace: PodNamespace,
		},
	}

	_, err := ct.clientSet.CoreV1().Pods(PodNamespace).Create(&pod)
	if err != nil {
		ct.t.Fatalf("error creating pod %v: %v", pod, err)
	}

	resetForTesting(func() { ct.t.Fatal("bad parse") })

	os.Setenv("POD_NAME", PodName)
	os.Setenv("POD_NAMESPACE", PodNamespace)
	// defer os.Setenv("POD_NAME", "")
	// defer os.Setenv("POD_NAMESPACE", "")

	ct.t.Logf("%v", ct.args)
	_, conf, err := readFlags(ct.args)
	if err != nil {
		ct.t.Errorf("Unexpected error creating NGINX controller: %v", err)
	}
	conf.Client = ct.clientSet

	fs, err := file.NewFakeFS()
	if err != nil {
		ct.t.Fatalf("Unexpected error: %v", err)
	}

	return controller.NewNGINXController(conf, metric.NewDummyCollector(), fs)
}

func (ct *configTest) AddConfigMap(newConfigMap v1.ConfigMap) {
	if ct.clientSet == nil {
		ct.clientSet = fake.NewSimpleClientset()
	}

	cm, err := ct.clientSet.CoreV1().ConfigMaps(PodNamespace).Create(&newConfigMap)
	if err != nil {
		ct.t.Errorf("error creating the configuration map: %v", err)
	}
	ct.t.Logf("Temporal configmap %v created", cm)
}

func (ct *configTest) AddIngress(newIngress v1beta1.Ingress) {
	if ct.clientSet == nil {
		ct.clientSet = fake.NewSimpleClientset()
	}

	ing, err := ct.clientSet.ExtensionsV1beta1().Ingresses(PodNamespace).Create(&newIngress)
	if err != nil {
		ct.t.Errorf("error creating the ingress map: %v", err)
	}
	ct.t.Logf("Temporal ingress %v created", ing)
}

func TestUseGeoIP2(t *testing.T) {
	ct := configTest{
		t: t,
	}
	ct.AddConfigMap(v1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: "fooconfig",
		},
		Data: map[string]string{
			"use-geoip2": "true",
		},
	})
	ct.args = []string{"cmd", "--configmap", PodNamespace + "/fooconfig"}

	conf := ct.GetController().TestSync()

	if !strings.Contains(conf, "/etc/nginx/modules/ngx_http_geoip2_module.so") {
		t.Fatalf("fuck")
	}
}

func TestProxyBufferSize(t *testing.T) {
	ct := configTest{
		t: t,
	}
	ct.AddConfigMap(v1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: "barconfig",
		},
		Data: map[string]string{},
	})
	ct.args = []string{"cmd", "--configmap", PodNamespace + "/barconfig"}

	ct.AddIngress(v1beta1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name: "testingress",
			Annotations: map[string]string{
				"nginx.ingress.kubernetes.io/proxy-buffer-size": "99k",
			},
		},
		Spec: v1beta1.IngressSpec{
			Backend: &v1beta1.IngressBackend{
				ServiceName: "foo-service",
				ServicePort: intstr.FromInt(8080),
			},
		},
	})

	conf := ct.GetController().TestSync()
	if !strings.Contains(conf, "99k") {
		t.Fatalf(conf)
	}
}

func TestHandleSigterm(t *testing.T) {
	ct := configTest{
		t: t,
	}
	ct.AddConfigMap(v1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name: "barconfig",
		},
		Data: map[string]string{},
	})
	ct.args = []string{"cmd", "--configmap", PodNamespace + "/barconfig"}

	ngx := ct.GetController()

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
