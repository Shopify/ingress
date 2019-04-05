/*
Copyright 2019 The Kubernetes Authors.

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

package plugin

import (
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"strings"

	"github.com/parnurzeal/gorequest"
)

type httpProvider struct {
}

// Fetch satisfies storageProvider interface.
// It retrieves a plugin archive from an HTTP/S location.
func (p *httpProvider) Fetch(archiveURL string) (string, error) {

	resp, data, errs := gorequest.New().Get(archiveURL).End()
	if len(errs) > 0 {
		return "", errs[0]
	}

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("Request returned with code %v", resp.StatusCode)
	}

	tmpfile, err := ioutil.TempFile("", "")
	if err != nil {
		return "", err
	}
	defer tmpfile.Close()

	_, err = io.Copy(tmpfile, strings.NewReader(data))
	if err != nil {
		os.Remove(tmpfile.Name())
		return "", err
	}

	return tmpfile.Name(), nil

}
