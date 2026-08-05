test:
	python3 run_tests.py

hello:
	python3 run_tests.py programs/hello.s

sierpinski:
	python3 run_tests.py programs/sierpinski.s

clean:
	rm -rf build

.PHONY: test hello sierpinski clean
