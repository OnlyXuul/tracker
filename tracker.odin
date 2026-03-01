package tracker

import "core:mem"
import "base:runtime"
import "core:strings"

import "shared:afmt"

//	At the top of your project import this package
//	import "shared:tracker"

/*	Copy-Paste this to top of main in your project

	when ODIN_DEBUG {
		//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true<br>
		t := tracker.init_tracker()
		context.allocator = tracker.tracking_allocator(&t)
		defer tracker.print_and_destroy_tracker(&t)
	}

*/

//	Default is to panic when a bad free is detected.
//	Override with: -define:nopanic=true
NOPANIC := #config(nopanic, false)

//	Default is to use ansi colors and formatting
//	Override with: -define:noansi=true
NOANSI := #config(noansi, false)

//	Alias so that only this tracker package needs to be imported and not also core:mem
tracking_allocator      :: mem.tracking_allocator

init_tracker :: proc() -> (t: mem.Tracking_Allocator) {
	mem.tracking_allocator_init(&t, context.allocator)
	if NOPANIC {
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

convert_bytes :: proc(size: $T) -> (f64, string) where T == uint || T == i64 {
	units := []string{"Bytes", "KBs", "MBs", "GBs", "TBs"}
	index := 0
	fsize := f64(size)

	for index = 0; fsize >= 1024 && index < len(units) - 1; index += 1 {
		fsize /= 1024.000  
	}

	if units[index] == "Bytes" {
		return fsize / 1024.000, "KBs"
	}

	return fsize, units[index]
}

//	Print allocations not freed and bad frees, then destroy tracker
print_and_destroy_tracker :: proc(t: ^mem.Tracking_Allocator) {

	header := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{074, 165, 240}, at = {.BOLD}}},
		{64, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{077, 196, 255}, at = {.BOLD}}},
	}

	metrics := [4]afmt.Column(afmt.ANSI24) {
		{16, .LEFT,  NOANSI ? {} : {fg = [3]u8{074, 165, 240}, bg = afmt.black, at = {.BOLD}}},
		{31, .LEFT,  NOANSI ? {} : {fg = [3]u8{077, 196, 255}, bg = afmt.black, at = {.BOLD}}},
		{1,  .LEFT,  NOANSI ? {} : {fg = [3]u8{077, 196, 255}, bg = afmt.black, at = {.BOLD}}},
		{32, .RIGHT, NOANSI ? {} : {fg = [3]u8{077, 196, 255}, bg = afmt.black, at = {.BOLD}}},
	}

	is_ok_title := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{140, 194, 101}, at = {.BOLD}}},
		{64, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{165, 224, 117}, at = {.BOLD}}},
	}

	not_ok_title := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{224, 085, 097}, at = {.BOLD}}},
		{64, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{255, 097, 110}, at = {.BOLD}}},
	}

	record_even := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{224, 216, 138}, at = {.BOLD}}},
		{64, .LEFT, NOANSI ? {} : {fg = [3]u8{238, 233, 172}, bg = afmt.black}},
	}

	record_odd := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{238, 233, 172}, at = {.BOLD}}},
		{64, .LEFT, NOANSI ? {} : {fg = [3]u8{238, 233, 172}, bg = afmt.black + 25}},
	}

	title:  [2]afmt.Column(afmt.ANSI24)
	record:	[2]afmt.Column(afmt.ANSI24)

	//	context.temp_allocator data
	temp_data := (^runtime.Default_Temp_Allocator)(context.temp_allocator.data)
	defer runtime.default_temp_allocator_destroy(temp_data)
	used := temp_data.arena.total_used
	cap  := temp_data.arena.total_capacity
	temp_lt := afmt.tprintf(" %v Bytes (%.2f %v)", used, convert_bytes(used))
	temp_rt := afmt.tprintf("%v Bytes (%.2f %v) ", cap, convert_bytes(cap))
	afmt.printrow(header, " Allocator", " context.temp_allocator")
	afmt.printrow(metrics, " Used/Capacity", temp_lt, "/", temp_rt)
	
	//	context.allocator
	//	Print Header
	afmt.printrow(header, " Allocator", " context.allocator")
	peak  := t.peak_memory_allocated
	total := t.total_memory_allocated
	ctx_lt := afmt.tprintf(" %v Bytes (%.2f %v)", peak, convert_bytes(peak))
	ctx_rt := afmt.tprintf("%v Bytes (%.2f %v) ", total, convert_bytes(total))
	afmt.printrow(metrics, " Peak/Allocated", ctx_lt, "/", ctx_rt)

	//	Print Allocations not freed
	title = len(t.allocation_map) == 0 ? is_ok_title : not_ok_title
	not_freed := len(t.allocation_map)
	allocated := t.total_allocation_count
	leaked := title == is_ok_title ? " 0 Bytes Leaked" : " Leaked Bytes"
	afmt.printrow(title, leaked, afmt.tprintf(" %d/%d Allocations Not Freed", not_freed, allocated))
	if len(t.allocation_map) > 0 {
		for _, entry in t.allocation_map {
			loc		:= entry.location
			label := afmt.tprintf(" %d", entry.size)
			field	:= afmt.tprintf(" %s:%i:%i", trim_path(loc.file_path), loc.line, loc.column)
			record = record == record_even ? record_odd : record_even
			length := len(field) + len(loc.procedure) + 1
			if length < 256 && length > 64 { record[1].width = u8(length) }
			afmt.printrow(record, label, afmt.tprintf("%s%*s", field, int(record[1].width) - len(field), loc.procedure))
		}
	}

	//	Print Incorrect frees
	if NOPANIC {
		title = len(t.bad_free_array) == 0 ? is_ok_title : not_ok_title
		bad_frees		:= len(t.bad_free_array)
		total_frees	:= i64(len(t.bad_free_array)) + t.total_free_count
		memory := title == is_ok_title ? " 0 Bad Frees" : " Memory Address"
		afmt.printrow(title, memory, afmt.tprintf(" %d/%d Bad Frees", bad_frees, total_frees))
		if len(t.bad_free_array) > 0 {
			for entry in t.bad_free_array {
				loc		:= entry.location
				label	:= afmt.tprintf(" %p", entry.memory)
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
