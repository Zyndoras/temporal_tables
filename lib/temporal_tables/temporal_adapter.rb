module TemporalTables
	module TemporalAdapter
		def self.included(base)
			base.class_eval do
				alias_method_chain :create_table,  :temporal
				alias_method_chain :drop_table,    :temporal
				alias_method_chain :rename_table,  :temporal
				alias_method_chain :add_column,    :temporal
				alias_method_chain :remove_column, :temporal
				alias_method_chain :change_column, :temporal

				def temporal_name(table_name)
					"#{table_name}_h"
				end

				def create_temporal_triggers(table_name)
					raise NotImplementedError, "create_temporal_triggers is not implemented"
				end

				def drop_temporal_triggers(table_name)
					raise NotImplementedError, "drop_temporal_triggers is not implemented"
				end
			end
		end

		def create_table_with_temporal(table_name, options = {}, &block)
			skip_table = TemporalTables.skipped_temporal_tables.include? table_name.to_sym

			create_table_without_temporal table_name, options do |t|
				block.call t

				if TemporalTables.add_updated_by_field && !skip_table
					t.column :updated_by, TemporalTables.updated_by_type
				end
			end

			if options[:temporal] || (TemporalTables.create_by_default && !skip_table)
				add_temporal_table table_name, options
			end
		end

		def add_temporal_table(table_name, options = {})
			create_table_without_temporal temporal_name(table_name), options.merge(:primary_key => "history_id") do |t|
				t.integer   :id
				t.timestamp :eff_from, :null => false
				t.timestamp :eff_to,   :null => false, :default => "9999-12-31"

				for c in columns(table_name)
					t.send c.type, c.name, :limit => c.limit
				end
			end
			create_temporal_triggers table_name
		end

		def remove_temporal_table(table_name)
			if table_exists?(temporal_name(table_name))
				drop_temporal_triggers table_name
				drop_table_without_temporal temporal_name(table_name)
			end
		end
		
		def drop_table_with_temporal(table_name, options = {})
			drop_table_without_temporal table_name, options

			if table_exists?(temporal_name(table_name))
				drop_table_without_temporal temporal_name(table_name), options
			end
		end

		def rename_table_with_temporal(name, new_name)
			if table_exists?(temporal_name(name))
				drop_temporal_triggers name
			end

			rename_table_without_temporal name, new_name

			if table_exists?(temporal_name(name))
				rename_table_without_temporal temporal_name(name), temporal_name(new_name)
				create_temporal_triggers new_name
			end
		end

		def add_column_with_temporal(table_name, column_name, type, options = {})
			add_column_without_temporal table_name, column_name, type, options

			if table_exists?(temporal_name(table_name))
				add_column_without_temporal temporal_name(table_name), column_name, type, options
				create_temporal_triggers table_name
			end
		end

		def remove_column_with_temporal(table_name, *column_names)
			remove_column_without_temporal table_name, *column_names

			if table_exists?(temporal_name(table_name))
				remove_column_without_temporal temporal_name(table_name), *column_names
				create_temporal_triggers table_name
			end
		end

		def change_column_with_temporal(table_name, column_name, type, options = {})
			change_column_without_temporal table_name, column_name, type, options

			if table_exists?(temporal_name(table_name))
				change_column_without_temporal temporal_name(table_name), column_name, type, options
				# Don't need to update triggers here...
			end
		end

		def rename_column_with_temporal(table_name, column_name, new_column_name)
			rename_column_without_temporal table_name, column_name, new_column_name

			if table_exists?(temporal_name(table_name))
				rename_column_without_temporal temporal_name(table_name), column_name, new_column_name
				create_temporal_triggers table_name
			end
		end
	end
end