package example

import "shared:tracker"

//	odin run . -debug

main :: proc () {
	when ODIN_DEBUG {
		tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true
		this_tracker := tracker.init_tracker()
		context.allocator = tracker.tracking_allocator(&this_tracker)
		defer tracker.print_and_destroy_tracker(&this_tracker)
	}

	test01 := make([dynamic]int, 8)
	test02 := make([dynamic]int, 8)
	test03 := make([dynamic]int, 8)
	test04 := make([dynamic]int, 8)
	test05 := make([dynamic]int, 8)
	test06 := make([dynamic]int, 8)
	test07 := make([dynamic]int, 8)
	test08 := make([dynamic]int, 8)
	test09 := make([dynamic]int, 8)
	delete(test01)
	delete(test02)
	delete(test03)
	delete(test04)
	delete(test05)
	delete(test06)
	delete(test07)
	delete(test08)
	delete(test09)
}