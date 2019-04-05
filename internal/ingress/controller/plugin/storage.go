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
	"crypto/sha256"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"

	"k8s.io/ingress-nginx/internal/ingress"
)

const pluginInstallDirectory = "/etc/nginx/lua/plugins"

var providers = map[string]storageProvider{
	"gs":    &gcsProvider{},
	"http":  &httpProvider{},
	"https": &httpProvider{},
}

// Setup will install a plugin archive to local `installDirectory`
// It automatically checks for archive sha256 sum.
// Archive MUST be a tar.gz encoded file.
func Setup(plugin ingress.Plugin) error {

	if plugin.Name == "" {
		return fmt.Errorf("plugin with sha %v and archive %v has no name", plugin.SHA256Sum, plugin.Archive)
	}

	provider, err := provider(plugin.Archive)
	if err != nil {
		return err
	}

	filename, err := provider.Fetch(plugin.Archive)
	if err != nil {
		return err
	}
	defer os.Remove(filename)

	err = checkSHA256(filename, plugin.SHA256Sum)
	if err != nil {
		return err
	}

	directory := pluginInstallDirectory + "/" + plugin.Name

	err = unarchive(filename, directory)
	if err != nil {
		return err
	}

	return nil
}

// provider returns a storage provider based on archive URL.
func provider(archiveURL string) (storageProvider, error) {
	u, err := url.Parse(archiveURL)
	if err != nil {
		return nil, err
	}

	providerName := u.Scheme
	provider, ok := providers[providerName]
	if !ok {
		return nil, fmt.Errorf("unknown storage provider '%s'", providerName)
	}

	return provider, nil
}

// checkSHA256 checks for `filename` sha256 sum.
// returns nil when valid.
func checkSHA256(filename, expectedSHA256 string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}

	h := sha256.New()
	_, err = io.Copy(h, file)
	if err != nil {
		return err
	}

	sha := fmt.Sprintf("%x", h.Sum(nil))
	if sha != expectedSHA256 {
		return fmt.Errorf("invalid sha256 for %s, got %s, expected %s", filename, sha, expectedSHA256)
	}

	return nil
}

// unarchive
func unarchive(filename, installDirectory string) error {
	mkdirCmd := exec.Command("mkdir", "-p", installDirectory)
	out, err := mkdirCmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("Could not create plugin install directory \"%v\": %v %v", installDirectory, string(out), err)
	}

	cmd := exec.Command("tar", "-xf", filename, "-C", installDirectory)
	out, err = cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf(`
-------------------------------------------------------------------------------
Error: %v
%v
-------------------------------------------------------------------------------
`, err, string(out))
	}

	return nil
}

type storageProvider interface {
	// Fetch retrieves the plugin archive from an url.
	// returns the path to the downloaded archive, and an error
	Fetch(url string) (string, error)
}
