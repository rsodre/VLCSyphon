/*****************************************************************************
 * bookmarks.m: MacOS X Bookmarks window
 *****************************************************************************
 * Copyright (C) 2005 - 2015 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne at videolan dot org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/


/*****************************************************************************
 * Note:
 * the code used to bind with VLC's modules is heavily based upon
 * ../wxwidgets/bookmarks.cpp, written by Gildas Bazin.
 * (he is a member of the VideoLAN team)
 *****************************************************************************/


/*****************************************************************************
 * Preamble
 *****************************************************************************/

#import "bookmarks.h"
#import "CompatibilityFixes.h"

@interface VLCBookmarks() <NSTableViewDataSource, NSTableViewDelegate>
{
    input_thread_t *p_old_input;
}
@end

@implementation VLCBookmarks

/*****************************************************************************
 * GUI methods
 *****************************************************************************/

- (id)init
{
    self = [super initWithWindowNibName:@"Bookmarks"];

    return self;
}

- (void)dealloc
{
    if (p_old_input)
        vlc_object_release(p_old_input);

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad
{
    [self.window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenAuxiliary];

    _dataTable.dataSource = self;
    _dataTable.delegate = self;
    _dataTable.action = @selector(goToBookmark:);
    _dataTable.target = self;

    /* main window */
    [self.window setTitle: _NS("Bookmarks")];
    [_addButton setTitle: _NS("Add")];
    [_clearButton setTitle: _NS("Clear")];
    [_editButton setTitle: _NS("Edit")];
    [_extractButton setTitle: _NS("Extract")];
    [_removeButton setTitle: _NS("Remove")];
    [[[_dataTable tableColumnWithIdentifier:@"description"] headerCell]
     setStringValue: _NS("Description")];
    [[[_dataTable tableColumnWithIdentifier:@"time_offset"] headerCell]
     setStringValue: _NS("Time")];

    /* edit window */
    [_editOKButton setTitle: _NS("OK")];
    [_editCancelButton setTitle: _NS("Cancel")];
    [_editNameLabel setStringValue: _NS("Name")];
    [_editTimeLabel setStringValue: _NS("Time")];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputChangedEvent:)
                                                 name:VLCInputChangedNotification
                                               object:nil];
}

- (void)updateCocoaWindowLevel:(NSInteger)i_level
{
    if (self.isWindowLoaded && [self.window isVisible] && [self.window level] != i_level)
        [self.window setLevel: i_level];
}

- (void)showBookmarks
{
    /* show the window, called from intf.m */
    [self.window displayIfNeeded];
    [self.window setLevel: [[[VLCMain sharedInstance] voutController] currentStatusWindowLevel]];
    [self.window makeKeyAndOrderFront:nil];
}

-(void)inputChangedEvent:(NSNotification *)o_notification
{
    [_dataTable reloadData];
}

- (IBAction)add:(id)sender
{
    /* add item to list */
    input_thread_t * p_input = pl_CurrentInput(getIntf());

    if (!p_input)
        return;

    seekpoint_t bookmark;

    if (!input_Control(p_input, INPUT_GET_BOOKMARK, &bookmark)) {
        bookmark.psz_name = _("Untitled");
        input_Control(p_input, INPUT_ADD_BOOKMARK, &bookmark);
    }

    vlc_object_release(p_input);

    [_dataTable reloadData];
}

- (IBAction)clear:(id)sender
{
    /* clear table */
    input_thread_t * p_input = pl_CurrentInput(getIntf());

    if (!p_input)
        return;

    input_Control(p_input, INPUT_CLEAR_BOOKMARKS);

    vlc_object_release(p_input);

    [_dataTable reloadData];
}

- (IBAction)edit:(id)sender
{
    /* put values to the sheet's fields and show sheet */
    /* we take the values from the core and not the table, because we cannot
     * really trust it */
    input_thread_t * p_input = pl_CurrentInput(getIntf());
    seekpoint_t **pp_bookmarks;
    int i_bookmarks;
    int row;
    row = [_dataTable selectedRow];

    if (!p_input)
        return;

    if (row < 0) {
        vlc_object_release(p_input);
        return;
    }

    if (input_Control(p_input, INPUT_GET_BOOKMARKS, &pp_bookmarks, &i_bookmarks) != VLC_SUCCESS) {
        vlc_object_release(p_input);
        return;
    }

    [_editNameTextField setStringValue: toNSStr(pp_bookmarks[row]->psz_name)];
    int total = pp_bookmarks[row]->i_time_offset/ 1000000;
    int hour = total / (60*60);
    int min = (total - hour*60*60) / 60;
    int sec = total - hour*60*60 - min*60;
    [_editTimeTextField setStringValue: [NSString stringWithFormat:@"%02d:%02d:%02d", hour, min, sec]];

    /* Just keep the pointer value to check if it
     * changes. Note, we don't need to keep a reference to the object.
     * so release it now. */
    p_old_input = p_input;
    vlc_object_release(p_input);

    [NSApp beginSheet: _editBookmarksWindow modalForWindow: self.window modalDelegate: _editBookmarksWindow didEndSelector: nil contextInfo: nil];

    // Clear the bookmark list
    for (int i = 0; i < i_bookmarks; i++)
        vlc_seekpoint_Delete(pp_bookmarks[i]);
    free(pp_bookmarks);
}

- (IBAction)edit_cancel:(id)sender
{
    /* close sheet */
    [NSApp endSheet:_editBookmarksWindow];
    [_editBookmarksWindow close];
}

- (IBAction)edit_ok:(id)sender
{
    /* save field contents and close sheet */
     seekpoint_t **pp_bookmarks;
    int i_bookmarks, i;
    input_thread_t * p_input = pl_CurrentInput(getIntf());

    if (!p_input) {
        NSBeginCriticalAlertSheet(_NS("No input"), _NS("OK"), @"", @"", self.window, nil, nil, nil, nil, @"%@",_NS("No input found. A stream must be playing or paused for bookmarks to work."));
        return;
    }
    if (p_old_input != p_input) {
        NSBeginCriticalAlertSheet(_NS("Input has changed"), _NS("OK"), @"", @"", self.window, nil, nil, nil, nil, @"%@",_NS("Input has changed, unable to save bookmark. Suspending playback with \"Pause\" while editing bookmarks to ensure to keep the same input."));
        vlc_object_release(p_input);
        return;
    }

    if (input_Control(p_input, INPUT_GET_BOOKMARKS, &pp_bookmarks, &i_bookmarks) != VLC_SUCCESS) {
        vlc_object_release(p_input);
        return;
    }

    i = [_dataTable selectedRow];

    free(pp_bookmarks[i]->psz_name);

    pp_bookmarks[i]->psz_name = strdup([[_editNameTextField stringValue] UTF8String]);

    NSArray * components = [[_editTimeTextField stringValue] componentsSeparatedByString:@":"];
    NSUInteger componentCount = [components count];
    if (componentCount == 1)
        pp_bookmarks[i]->i_time_offset = 1000000LL * ([[components firstObject] longLongValue]);
    else if (componentCount == 2)
        pp_bookmarks[i]->i_time_offset = 1000000LL * ([[components firstObject] longLongValue] * 60 + [[components objectAtIndex:1] longLongValue]);
    else if (componentCount == 3)
        pp_bookmarks[i]->i_time_offset = 1000000LL * ([[components firstObject] longLongValue] * 3600 + [[components objectAtIndex:1] longLongValue] * 60 + [[components objectAtIndex:2] longLongValue]);
    else {
        msg_Err(getIntf(), "Invalid string format for time");
        goto clear;
    }

    if (input_Control(p_input, INPUT_CHANGE_BOOKMARK, pp_bookmarks[i], i) != VLC_SUCCESS) {
        msg_Warn(getIntf(), "Unable to change the bookmark");
        goto clear;
    }

    [_dataTable reloadData];
    vlc_object_release(p_input);

    [NSApp endSheet: _editBookmarksWindow];
    [_editBookmarksWindow close];

clear:
    // Clear the bookmark list
    for (int i = 0; i < i_bookmarks; i++)
        vlc_seekpoint_Delete(pp_bookmarks[i]);
    free(pp_bookmarks);
}

- (IBAction)extract:(id)sender
{
#warning this does not work anymore
#if 0
    if ([_dataTable numberOfSelectedRows] < 2) {
        NSBeginAlertSheet(_NS("Invalid selection"), _NS("OK"), @"", @"", self.window, nil, nil, nil, nil, @"%@",_NS("Two bookmarks have to be selected."));
        return;
    }
    input_thread_t * p_input = pl_CurrentInput(getIntf());
    if (!p_input) {
        NSBeginCriticalAlertSheet(_NS("No input found"), _NS("OK"), @"", @"", self.window, nil, nil, nil, nil, @"%@",_NS("The stream must be playing or paused for bookmarks to work."));
        return;
    }

    seekpoint_t **pp_bookmarks;
    int i_bookmarks ;
    int i_first = -1;
    int i_second = -1;
    int c = 0;
    for (NSUInteger x = 0; c != 2; x++) {
        if ([_dataTable isRowSelected:x]) {
            if (i_first == -1) {
                i_first = x;
                c = 1;
            } else if (i_second == -1) {
                i_second = x;
                c = 2;
            }
        }
    }

    if (input_Control(p_input, INPUT_GET_BOOKMARKS, &pp_bookmarks, &i_bookmarks) != VLC_SUCCESS) {
        vlc_object_release(p_input);
        msg_Err(getIntf(), "already defined bookmarks couldn't be retrieved");
        return;
    }

    char *psz_uri = input_item_GetURI(input_GetItem(p_input));
    [[[VLCMain sharedInstance] wizard] initWithExtractValuesFrom: [NSString stringWithFormat:@"%lli", pp_bookmarks[i_first]->i_time_offset/1000000] to: [NSString stringWithFormat:@"%lli", pp_bookmarks[i_second]->i_time_offset/1000000] ofItem: toNSStr(psz_uri)];
    free(psz_uri);
    vlc_object_release(p_input);

    // Clear the bookmark list
    for (int i = 0; i < i_bookmarks; i++)
        vlc_seekpoint_Delete(pp_bookmarks[i]);
    free(pp_bookmarks);
#endif
}

- (IBAction)goToBookmark:(id)sender
{
    input_thread_t * p_input = pl_CurrentInput(getIntf());

    if (!p_input)
        return;

    input_Control(p_input, INPUT_SET_BOOKMARK, [_dataTable selectedRow]);

    vlc_object_release(p_input);
}

- (IBAction)remove:(id)sender
{
    input_thread_t * p_input = pl_CurrentInput(getIntf());

    if (!p_input)
        return;

    int i_focused = [_dataTable selectedRow];

    if (i_focused >= 0)
        input_Control(p_input, INPUT_DEL_BOOKMARK, i_focused);

    vlc_object_release(p_input);

    [_dataTable reloadData];
}

/*****************************************************************************
 * data source methods
 *****************************************************************************/

- (NSInteger)numberOfRowsInTableView:(NSTableView *)theDataTable
{
    /* return the number of bookmarks */
    input_thread_t * p_input = pl_CurrentInput(getIntf());
    seekpoint_t **pp_bookmarks;
    int i_bookmarks;

    if (!p_input)
        return 0;

    int returnValue = input_Control(p_input, INPUT_GET_BOOKMARKS, &pp_bookmarks, &i_bookmarks);
    vlc_object_release(p_input);

    if (returnValue != VLC_SUCCESS)
        return 0;

    for (int i = 0; i < i_bookmarks; i++)
        vlc_seekpoint_Delete(pp_bookmarks[i]);
    free(pp_bookmarks);

    return i_bookmarks;
}

- (id)tableView:(NSTableView *)theDataTable objectValueForTableColumn: (NSTableColumn *)theTableColumn row: (NSInteger)row
{
    /* return the corresponding data as NSString */
    input_thread_t * p_input = pl_CurrentInput(getIntf());
    seekpoint_t **pp_bookmarks;
    int i_bookmarks;
    id ret = @"";

    if (!p_input)
        return @"";
    else if (input_Control(p_input, INPUT_GET_BOOKMARKS, &pp_bookmarks, &i_bookmarks) != VLC_SUCCESS)
        ret = @"";
    else if (row >= i_bookmarks)
        ret = @"";
    else {
        NSString * identifier = [theTableColumn identifier];
        if ([identifier isEqualToString: @"description"])
            ret = toNSStr(pp_bookmarks[row]->psz_name);
		else if ([identifier isEqualToString: @"time_offset"]) {
            int total = pp_bookmarks[row]->i_time_offset/ 1000000;
            int hour = total / (60*60);
            int min = (total - hour*60*60) / 60;
            int sec = total - hour*60*60 - min*60;
            ret = [NSString stringWithFormat:@"%02d:%02d:%02d", hour, min, sec];
        }

        // Clear the bookmark list
        for (int i = 0; i < i_bookmarks; i++)
            vlc_seekpoint_Delete(pp_bookmarks[i]);
        free(pp_bookmarks);
    }
    vlc_object_release(p_input);
    return ret;
}

/*****************************************************************************
 * delegate methods
 *****************************************************************************/

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    /* check whether a row is selected and en-/disable the edit/remove buttons */
    if ([_dataTable selectedRow] == -1) {
        /* no row is selected */
        [_editButton setEnabled: NO];
        [_removeButton setEnabled: NO];
        [_extractButton setEnabled: NO];
    } else {
        /* a row is selected */
        [_editButton setEnabled: YES];
        [_removeButton setEnabled: YES];
        if ([_dataTable numberOfSelectedRows] == 2)
            [_extractButton setEnabled: YES];
    }
}

@end
