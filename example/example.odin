package example

import "shared:tracker"

//	odin run . -debug -define:nopanic=true

main :: proc () {
	when ODIN_DEBUG {
		//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true
		t := tracker.init()
		context.allocator = t.allocator
		defer tracker.print_and_destroy(&t)
	}

	test01 := make([dynamic]int, 1)
	test02 := make([dynamic]int, 2)
	test03 := make([dynamic]int, 3)
	test04 := make([dynamic]int, 4)
	test05 := make([dynamic]int, 5)
	test06 := make([dynamic]int, 6)
	test07 := make([dynamic]int, 7)
	test08 := make([dynamic]int, 8)
	test09 := make([dynamic]int, 9)
	delete(test01)
	delete(test01)
	delete(test01)
	delete(test01)
	delete(test01)
	delete(test01)
	delete(test01)
	delete(test01)
	delete(test01)
}