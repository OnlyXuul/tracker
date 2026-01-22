package tracker

import "core:mem"
import "base:runtime"
import "core:strings"

import "shared:afmt"

//	At the top of your project import this package
//	import "shared:tracker"

/*	Copy-Paste this to top of main in your project

	when ODIN_DEBUG {
		t := tracker.init_tracker()
		context.allocator = tracker.tracking_allocator(&t)
		defer tracker.print_and_destroy_tracker(&t)
	}

*/

//	Default is to panic when a bad free is detected.
//	Override with: -define:panic=false
PANIC :: #config(panic, true)

//	Alias so that only this tracker package needs to be imported and not also core:mem
tracking_allocator      :: mem.tracking_allocator

init_tracker :: proc() -> (t: mem.Tracking_Allocator) {
	mem.tracking_allocator_init(&t, context.allocator)
	if !PANIC {
		t.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	}
	return
}

//	Trim long paths to something more readable if possible without allocating any dynamic memory
trim_path :: proc(file_path: string) -> (path: string) {
	if index := strings.last_index(file_path, ODIN_BUILD_PROJECT_NAME); index >= 0 {
		path = file_path[index:]
	} else if strings.contains(file_path, ODIN_ROOT) {
		path = file_path[len(ODIN_ROOT):]
	} else {
		path = file_path
	}
	return
}

//	Print allocations not freed and bad frees, then destroy tracker
print_and_destroy_tracker :: proc(t: ^mem.Tracking_Allocator) {

	header := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, {fg = afmt.black, bg = [3]u8{074, 165, 240}, at = {.BOLD}}},
		{64, .LEFT, {fg = afmt.black, bg = [3]u8{077, 196, 255}, at = {.BOLD}}}
	}

	is_ok_title := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, {fg = afmt.black, bg = [3]u8{140, 194, 101}, at = {.BOLD}}},
		{64, .LEFT, {fg = afmt.black, bg = [3]u8{165, 224, 117}, at = {.BOLD}}},
	}

	not_ok_title := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, {fg = afmt.black, bg = [3]u8{224, 085, 097}, at = {.BOLD}}},
		{64, .LEFT, {fg = afmt.black, bg = [3]u8{255, 097, 110}, at = {.BOLD}}},
	}

	record_even := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, {fg = afmt.black, bg = [3]u8{224, 216, 138}, at = {.BOLD}}},
		{64, .LEFT, {fg = [3]u8{238, 233, 172}, bg = afmt.black}},
	}

	record_odd := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, {fg = afmt.black, bg = [3]u8{238, 233, 172}, at = {.BOLD}}},
		{64, .LEFT, {fg = [3]u8{238, 233, 172}, bg = afmt.black + 25}},
	}

	title:  [2]afmt.Column(afmt.ANSI24)
	record:	[2]afmt.Column(afmt.ANSI24)
	
	//	Print Header
	peak_total := afmt.tprintf(" %d / %d Bytes", t.peak_memory_allocated, t.total_memory_allocated)
	afmt.printrow(header, " Peak/Allocated", peak_total)

	//	Print Allocations not freed
	title = len(t.allocation_map) == 0 ? is_ok_title : not_ok_title
	not_freed := len(t.allocation_map)
	allocated := t.total_allocation_count
	afmt.printrow(title, afmt.tprintf(" %d/%d", not_freed, allocated), " Allocations Not Freed")
	if len(t.allocation_map) > 0 {
		for _, entry in t.allocation_map {
			loc		:= entry.location
			label := afmt.tprintf("%9d %s ", entry.size, "Bytes")
			field	:= afmt.tprintf(" %s:%i:%i", trim_path(loc.file_path), loc.line, loc.column)
			record = record == record_even ? record_odd : record_even
			length := len(field) + len(loc.procedure) + 1
			if length < 256 && length > 64 { record[1].width = u8(length) }
			afmt.printrow(record, label, afmt.tprintf("%s%*s", field, int(record[1].width) - len(field), loc.procedure))
		}
	}

	//	Print Incorrect frees
	if !PANIC {
		title = len(t.allocation_map) == 0 ? is_ok_title : not_ok_title
		bad_frees		:= len(t.bad_free_array)
		total_frees	:= i64(len(t.bad_free_array)) + t.total_free_count
		afmt.printrow(title, afmt.tprintf(" %d/%d", bad_frees, total_frees), " Incorrect Frees")
		if len(t.bad_free_array) > 0 {
			for entry in t.bad_free_array {
				loc		:= entry.location
				label	:= afmt.tprintf("%p", entry.memory)
				field	:= afmt.tprintf(" %s:%i:%i", trim_path(loc.file_path), loc.line, loc.column)
				record = record == record_even ? record_odd : record_even
				length := len(field) + len(loc.procedure) + 1
				if length < 256 && length > 64 { record[1].width = u8(length) }
				afmt.printrow(record, label, afmt.tprintf("%s%*s", field, int(record[1].width) - len(field), loc.procedure))
			}
		}
	}

	//	Done and destroy tracker
	mem.tracking_allocator_destroy(t)
}
