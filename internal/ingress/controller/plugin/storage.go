package plugin

import (
	"crypto/sha256"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
)

var providers = map[string]storageProvider{
	"gs": &gcsProvider{},
}

// Setup will install a plugin archive to local `installDirectory`
// It automatically checks for archive sha256 sum.
// Archive MUST be a tar.gz encoded file.
func Setup(archiveURL, expectedSHA256, installDirectory string) error {

	provider, err := provider(archiveURL)
	if err != nil {
		return err
	}

	filename, err := provider.Fetch(archiveURL)
	if err != nil {
		return err
	}
	defer os.Remove(filename)

	err = checkSHA256(filename, expectedSHA256)
	if err != nil {
		return err
	}

	err = unarchive(filename, installDirectory)
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

	cmd := exec.Command("tar", "-xf", filename, "-C", installDirectory)
	out, err := cmd.CombinedOutput()
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
