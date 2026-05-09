package tracker

import "core:mem"
import "base:runtime"
import "core:strings"

//	afmt is a required import which is availible on my git page
import "shared:afmt"

//	At the top of your project import this package
//	import "shared:tracker"

//	Non-Global Tracker

/*	Copy-Paste this to top of main in your project
	when ODIN_DEBUG {
		//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true
		t := tracker.init()
		context.allocator = t.allocator
		defer tracker.print_and_destroy(&t)
	}
*/

//	Global Tracker - 3 parts

/*	Part 1 - Copy-Paste this in init procedure like in wasm
	when ODIN_DEBUG {
		//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true
		tracker.init_global()
		context.allocator = tracker.global.allocator
		defer tracker.print_and_destroy(&tracker.global)
	}
*/

/*	Part 2 - Copy and paste this to the beginning of every procedure you wish tracker to collect data for
	when ODIN_DEBUG {
		context.allocator = tracker.global.allocator
	}
*/

/*	Part 3 - Copy and past this in the final procedure like shutdown in wasm
	when ODIN_DEBUG {
		context.allocator = tracker.global.allocator
		defer tracker.print_and_destroy(&tracker.global)
	}
*/

//	Default is to panic when a bad free is detected.
//	Override with: -define:nopanic=true
NOPANIC := #config(nopanic, false)

//	Default is to use ansi colors and formatting
//	Override with: -define:noansi=true
NOANSI := #config(noansi, false)

Tracker :: struct {
	data:      ^mem.Tracking_Allocator,
	allocator: mem.Allocator,
}

//	Useful if wishing to use tracker independent of main, like with wasm programs
global: Tracker

panic_allocator    :: mem.tracking_allocator_bad_free_callback_panic
no_panic_allocator :: mem.tracking_allocator_bad_free_callback_add_to_array

init :: proc() -> (t: Tracker) {
	t.data = new(mem.Tracking_Allocator, context.allocator)
	mem.tracking_allocator_init(t.data, context.allocator)
	t.data.bad_free_callback = NOPANIC ? no_panic_allocator : panic_allocator
	t.allocator = mem.tracking_allocator(t.data)
	return
}

init_global :: proc() -> (Tracker) {
	global.data = new(mem.Tracking_Allocator, context.allocator)
	mem.tracking_allocator_init(global.data, context.allocator)
	global.data.bad_free_callback = NOPANIC ? no_panic_allocator : panic_allocator
	global.allocator = mem.tracking_allocator(global.data)
	return global
}

destroy :: proc(t: ^Tracker) {
	mem.tracking_allocator_destroy(t.data)
	//restore context.allocator so we can free allocated pointer
	context.allocator = runtime.default_allocator()
	free(t.data)
}

print_and_destroy :: proc(t: ^Tracker) {
	print(t^)
	destroy(t)
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
print :: proc(t: Tracker) {

	header := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{074, 165, 240}, at = {.bold}}},
		{64, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{077, 196, 255}, at = {.bold}}},
	}

	metrics := [4]afmt.Column(afmt.ANSI24) {
		{16, .LEFT,  NOANSI ? {} : {fg = [3]u8{074, 165, 240}, bg = afmt.black, at = {.bold}}},
		{31, .LEFT,  NOANSI ? {} : {fg = [3]u8{077, 196, 255}, bg = afmt.black, at = {.bold}}},
		{1,  .LEFT,  NOANSI ? {} : {fg = [3]u8{077, 196, 255}, bg = afmt.black, at = {.bold}}},
		{32, .RIGHT, NOANSI ? {} : {fg = [3]u8{077, 196, 255}, bg = afmt.black, at = {.bold}}},
	}

	is_ok_title := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{140, 194, 101}, at = {.bold}}},
		{64, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{165, 224, 117}, at = {.bold}}},
	}

	not_ok_title := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{224, 085, 097}, at = {.bold}}},
		{64, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{255, 097, 110}, at = {.bold}}},
	}

	record_even := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{224, 216, 138}, at = {.bold}}},
		{64, .LEFT, NOANSI ? {} : {fg = [3]u8{238, 233, 172}, bg = afmt.black}},
	}

	record_odd := [2]afmt.Column(afmt.ANSI24) {
		{16, .LEFT, NOANSI ? {} : {fg = afmt.black, bg = [3]u8{238, 233, 172}, at = {.bold}}},
		{64, .LEFT, NOANSI ? {} : {fg = [3]u8{238, 233, 172}, bg = afmt.black + 25}},
	}

	title:  [2]afmt.Column(afmt.ANSI24)
	record: [2]afmt.Column(afmt.ANSI24)

	//	context.temp_allocator metrics
	used    := (^runtime.Default_Temp_Allocator)(context.temp_allocator.data).arena.total_used
	cap     := (^runtime.Default_Temp_Allocator)(context.temp_allocator.data).arena.total_capacity
	temp_lt := afmt.tprintf(" %v Bytes (%.2f %v)", used, convert_bytes(used))
	temp_rt := afmt.tprintf("%v Bytes (%.2f %v) ", cap, convert_bytes(cap))
	afmt.printrow(header, " Allocator", " context.temp_allocator")
	afmt.printrow(metrics, " Used/Capacity", temp_lt, "/", temp_rt)
	
	//	context.allocator metrics
	afmt.printrow(header, " Allocator", " context.allocator")
	peak   := t.data.peak_memory_allocated
	total  := t.data.total_memory_allocated
	ctx_lt := afmt.tprintf(" %v Bytes (%.2f %v)", peak, convert_bytes(peak))
	ctx_rt := afmt.tprintf("%v Bytes (%.2f %v) ", total, convert_bytes(total))
	afmt.printrow(metrics, " Peak/Allocated", ctx_lt, "/", ctx_rt)

	//	Print Allocations not freed
	title      = len(t.data.allocation_map) == 0 ? is_ok_title : not_ok_title
	leaked    := title == is_ok_title ? " 0 Bytes Leaked" : " Leaked Bytes"
	not_freed := len(t.data.allocation_map)
	allocated := t.data.total_allocation_count
	afmt.printrow(title, leaked, afmt.tprintf(" %d/%d Allocations Not Freed", not_freed, allocated))
	if len(t.data.allocation_map) > 0 {
		for _, entry in t.data.allocation_map {
			loc    := entry.location
			label  := afmt.tprintf(" %d", entry.size)
			field  := afmt.tprintf(" %s:%i:%i", trim_path(loc.file_path), loc.line, loc.column)
			record  = record == record_even ? record_odd : record_even
			length := len(field) + len(loc.procedure) + 1
			if length < 256 && length > 64 { record[1].width = u8(length) }
			afmt.printrow(record, label, afmt.tprintf("%s%*s", field, int(record[1].width) - len(field), loc.procedure))
		}
	}

	//	Print Incorrect frees
	if NOPANIC {
		title        = len(t.data.bad_free_array) == 0 ? is_ok_title : not_ok_title
		memory      := title == is_ok_title ? " 0 Bad Frees" : " Memory Address"
		bad_frees   := len(t.data.bad_free_array)
		total_frees := i64(len(t.data.bad_free_array)) + t.data.total_free_count
		afmt.printrow(title, memory, afmt.tprintf(" %d/%d Bad Frees", bad_frees, total_frees))
		if len(t.data.bad_free_array) > 0 {
			for entry in t.data.bad_free_array {
				loc    := entry.location
				label  := afmt.tprintf(" %p", entry.memory)
				field  := afmt.tprintf(" %s:%i:%i", trim_path(loc.file_path), loc.line, loc.column)
				record  = record == record_even ? record_odd : record_even
				length := len(field) + len(loc.procedure) + 1
				if length < 256 && length > 64 { record[1].width = u8(length) }
				afmt.printrow(record, label, afmt.tprintf("%s%*s", field, int(record[1].width) - len(field), loc.procedure))
			}
		}
	}
}
