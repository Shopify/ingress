package plugin

import (
	"context"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net/url"
	"os"
	"strings"

	gcs "cloud.google.com/go/storage"
)

var (
	ErrInvalidGCSURL = errors.New("invalid gcs URL")
)

type gcsProvider struct {
}

// Parse returns the bucket and filename from a gcs URL.
func (p *gcsProvider) Parse(archiveURL string) (bucket, filename string, err error) {
	var u *url.URL
	u, err = url.Parse(archiveURL)
	if err != nil {
		return
	}

	bucket = u.Host
	filename = strings.TrimLeft(u.Path, "/")

	if u.Scheme != "gs" ||
		bucket == "" ||
		filename == "" {
		err = ErrInvalidGCSURL
		return
	}

	return
}

// Fetch satisfies storageProvider interface.
// It retrieves a plugin archive from a Google Cloud Storage bucket.
func (p *gcsProvider) Fetch(archiveURL string) (string, error) {

	client, err := gcs.NewClient(context.Background())
	if err != nil {
		return "", err
	}

	bucket, filename, err := p.Parse(archiveURL)
	if err != nil {
		return "", err
	}

	reader, err := client.Bucket(bucket).Object(filename).NewReader(context.Background())
	if err != nil {
		return "", fmt.Errorf("could not retrieve file in bucket: %v", err)
	}

	tmpfile, err := ioutil.TempFile("", filename)
	if err != nil {
		return "", err
	}
	defer tmpfile.Close()

	_, err = io.Copy(tmpfile, reader)
	if err != nil {
		os.Remove(tmpfile.Name())
		return "", err
	}

	return tmpfile.Name(), nil

}
