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

import "testing"

func Test_gcsProvider_Parse(t *testing.T) {
	p := &gcsProvider{}

	testCases := []struct {
		archiveURL       string
		expectedBucket   string
		expectedFilename string
		expectedErr      error
	}{
		{
			archiveURL:       "gs://my-bucket/myfile.tar.gz",
			expectedBucket:   "my-bucket",
			expectedFilename: "myfile.tar.gz",
			expectedErr:      nil,
		},
		{
			archiveURL:       "gs://my-bucket/sub_directory/myfile.tar.gz",
			expectedBucket:   "my-bucket",
			expectedFilename: "sub_directory/myfile.tar.gz",
			expectedErr:      nil,
		},
		{
			archiveURL:  "gs://my-bucket/",
			expectedErr: ErrInvalidGCSURL,
		},

		{
			archiveURL:  "http://localhost/myfile.tar.gz",
			expectedErr: ErrInvalidGCSURL,
		},
	}

	for _, c := range testCases {

		bucket, filename, err := p.Parse(c.archiveURL)
		if err != c.expectedErr {
			t.Errorf("unexpected err, got %v, expected %v", err, c.expectedErr)
		}
		if c.expectedErr != nil {
			continue
		}
		if bucket != c.expectedBucket {
			t.Errorf("unexpected bucket, got %v, expected %v", bucket, c.expectedBucket)
		}

		if filename != c.expectedFilename {
			t.Errorf("unexpected filename, got %v, expected %v", filename, c.expectedFilename)
		}

	}

}
