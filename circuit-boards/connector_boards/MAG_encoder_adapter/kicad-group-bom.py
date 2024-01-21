#!/usr/bin/python3

import csv
import sys
import os
from collections import OrderedDict
import argparse

def verify_file_exists(file_path):
    # Check if the file exists and return True or False
    return os.path.isfile(file_path)


def read_csv_to_dict(csv_file, skip_rows):
    with open(csv_file, 'r') as file:
        csv_reader = csv.reader(file)

        for _ in range(skip_rows):
            next(csv_reader)

        header_row = next(csv_reader)
        
        remaining_lines = []
        for line in csv_reader:
            line_dict = dict(zip(header_row, line))
            remaining_lines.append(line_dict)
        
        return header_row, remaining_lines


def get_header_from_dict(dict_list):
    unique_keys = OrderedDict()
    for d in dict_list:
        for key in d.keys():
            unique_keys[key] = None
    keys = list(unique_keys.keys())
    return keys


def export_list_of_dicts_to_csv(dict_list, csv_filename):
    keys = get_header_from_dict(dict_list)
    with open(csv_filename, 'w') as csv_file:
        for key in keys:
                if key == 'LibPart' or key == 'Footprint' or key == 'Datasheet' or key == 'DNP':
                    continue
                
                print(f"{key}, ", end='', file=csv_file)
        print(file=csv_file)
        for d in dict_list:
            j = 0
            for key in keys:
                if key == 'LibPart' or key == 'Footprint' or key == 'Datasheet' or key == 'DNP':
                    continue

                i = 0
                if j == 0:
                    print(f'"', end='', file=csv_file)
                else:
                     print(f',"', end='', file=csv_file)
                j += 1
                for item in d[key]:
                    if i == 0:
                        print(f"{item}", end='', file=csv_file)
                    else:
                        print(f",{item}", end='', file=csv_file)
                    i += 1
                print(f'"', end='', file=csv_file) 
            print(file=csv_file)


def group_by_field(data, group_field):
    grouped_data = {}

    for item in data:
        group_value = item.get(group_field)

        if group_value is not None:
            if group_value not in grouped_data:
                grouped_data[group_value] = []

            grouped_data[group_value].append(item)

    return grouped_data


def merge_dicts(dict_list):
    merged_dict = {}

    # Iterate through each dictionary in the list
    for d in dict_list:
        # Iterate through key-value pairs in the dictionary
        for key, value in d.items():
            # Append the value to the existing content for the corresponding key if not already present
            if key in merged_dict:
                if value not in merged_dict[key]:
                    merged_dict[key].append(value)
                    #merged_dict[key] += [value]
            else:
                # If the key is not in the merged dictionary, create a new list with the value
                merged_dict[key] = [value]
    return merged_dict


def convert_consecutive_references(raw_references_list):
    references_str = raw_references_list[0].strip()
    references = [item.strip() for item in references_str.split(',')]

    if not isinstance(references, list):
        print(f"Unexpected data type for 'Reference(s)': {type(references)}")
        return references, len(references)

    grouped_references = []
    current_group = []

    def add_group_to_result(group):
        if len(group) > 1:
            grouped_references.append(f"{group[0]}-{group[-1]}")
        else:
            grouped_references.extend(group)

    for ref in sorted(references, key=lambda x: [c.isdigit() for c in x]):
        if not current_group or not is_consecutive(current_group[-1], ref):
            add_group_to_result(current_group)
            current_group = [ref]
        else:
            current_group.append(ref)

    add_group_to_result(current_group)

    return grouped_references, len(references)

def is_consecutive(reference1, reference2):
    try:
        num_part_1 = int(''.join(c for c in reference1 if c.isdigit()))
        num_part_2 = int(''.join(c for c in reference2 if c.isdigit()))
        return num_part_1 + 1 == num_part_2
    except ValueError:
        return False

def flatten_and_concatenate_with_count(data):
    result = [item.replace(' ', '').split(',') for item in data]
    flattened_list = [element for sublist in result for element in sublist]
    concatenated_string = ','.join(flattened_list)
    return concatenated_string, len(flattened_list)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', help='input csv file')
    parser.add_argument('-o', '--output', help='output csv file')
    parser.add_argument('-d', '--dnp', action='store_true', help='include DNP components in BOM')
    parser.add_argument('-k', '--key', help='group key (default: MFG P/N)')
    parser.add_argument('-n', '--skip_rows', help='number of rows to skip before header row (default: 8)')

    args = parser.parse_args()
    
    if args.input == None or args.output == None:
        parser.print_help()
        exit()

    if args.input == None:
        print("Missing input file")
        exit()
    if args.output == None:
        print("Missing output file")
        exit()

    if args.key == None:
        group_key = "MFG P/N"
    else:
        group_key = args.key
    
    dnp_key = 'DNP'

    if args.skip_rows == None:
        skip_rows = 8
    else:
        skip_rows = int(args.skip_rows)

    bom_file = args.input 
    bom_output_file = args.output

    if verify_file_exists(bom_file) == False:
        print("File does not exist")
        exit()

    header_row, bom_data = read_csv_to_dict(bom_file, skip_rows)

    group_by_dnp = group_by_field(bom_data, 'DNP')

    grouped_data = []
    item_num = 1
    for group, group_by_dnp_data in group_by_dnp.items():
        group_by_pn = group_by_field(group_by_dnp_data, group_key)
        for pn, grp_pn_data in group_by_pn.items():
            grouped_data_dict = merge_dicts(grp_pn_data)
            #ref_des_list, qty = convert_consecutive_references(grouped_data_dict['Reference(s)']) 
            ref_des_list, qty = flatten_and_concatenate_with_count(grouped_data_dict['Reference(s)'])
            grouped_data_dict['Reference(s)'] = [ref_des_list]
            grouped_data_dict['Qty'] = [qty]
            grouped_data_dict['Item'] = [item_num]
            if args.dnp == False and grouped_data_dict['DNP'] == ['DNP']:
                continue
            
            item_num += 1
            grouped_data += [grouped_data_dict]

    if args.dnp == False and grouped_data_dict['DNP'] == ['DNP']:
        grouped_dnp_dict = merge_dicts(group_by_dnp[dnp_key])
        refs = grouped_dnp_dict['Reference(s)']
        ref_des_list, qty = flatten_and_concatenate_with_count(refs) 
        
        keys = get_header_from_dict(grouped_data) 
        for key in keys:
            grouped_dnp_dict[key] = ['']

        grouped_dnp_dict['Reference(s)'] = [ref_des_list]
        grouped_dnp_dict['Qty'] = [qty]
        grouped_dnp_dict['Item'] = [item_num]
        grouped_dnp_dict['Value'] = ['DNP']
        grouped_data += [grouped_dnp_dict] 

    export_list_of_dicts_to_csv(grouped_data, bom_output_file)

if __name__ == "__main__":
    main()

