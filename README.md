# LazyList

[![Build Status](https://app.bitrise.io/app/3b6ba7d7fa34810f/status.svg?token=mViSVG__-ADbnwL0xXiObQ&branch=master)](https://app.bitrise.io/app/3b6ba7d7fa34810f)

The `LazyList` represents a data structure which makes paging and lazy loading of
list data simpler.


## Tests

### Naming convention

Inspired by [3 Most Important Parts of the Best Unit Test Names](https://qualitycoding.org/unit-test-names/)

```
test_methodName_withCertainState_shouldDoSomething
```


# TODOs

- allow cancellation of requests
- refactor size() to count property
- add API to specify cache size for LazyList (and PagedLazyList)
