test:
	python3 run_tests.py

compliance:
	python3 compliance/run_compliance.py

hello:
	python3 run_tests.py programs/hello.s

sierpinski:
	python3 run_tests.py programs/sierpinski.s

clean:
	rm -rf build

.PHONY: test compliance hello sierpinski clean
