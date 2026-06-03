package app

import (
	"errors"
	"os"
	"syscall"
)

var defaultOpenContent = func(url string) (int, error) {
	return -1, errors.New("not implement")
}

var openContentImpl = defaultOpenContent

func OpenContent(url string) (*os.File, error) {
	fd, err := openContentImpl(url)

	if err != nil {
		return nil, err
	}

	_ = syscall.SetNonblock(fd, true)

	return os.NewFile(uintptr(fd), "fd"), nil
}

func ApplyContentContext(openContent func(string) (int, error)) {
	if openContent == nil {
		openContent = defaultOpenContent
	}

	openContentImpl = openContent
}
