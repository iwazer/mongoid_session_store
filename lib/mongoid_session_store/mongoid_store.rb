# -*- coding: utf-8 -*-
module ActionDispatch
  module Session
    class MongoidStore < AbstractStore

      def self.collection_name= name
        @collection_name = name
      end

      def self.collection_name
        @collection_name ||= 'sessions'
      end

      class Session
        include Mongoid::Document
        include Mongoid::Timestamps

        store_in collection: ->{MongoidStore.collection_name}

        field :id, type: String
        field :data, type: String, default: [Marshal.dump({})].pack("m*")
      end

      # The class used for session storage.
      cattr_accessor :session_class
      self.session_class = Session

      SESSION_RECORD_KEY = 'rack.session.record'
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY if ::Rails.version >= "3.1"

      private

        def get_session(env, sid)
          sid ||= generate_sid
          session = find_session(sid)
          env[SESSION_RECORD_KEY] = session
          [sid, unpack(session.data)]
        end

        def set_session(env, sid, session_data, options = nil)
          record = get_session_model(env, sid)
          record.data = pack(session_data)

          # Rack spec dictates that set_session should return true or false
          # depending on whether or not the session was saved or not.
          # However, ActionPack seems to want a session id instead.
          record.save ? sid : false
        end

        def find_session(id)
          # ReplicaSetを利用していてconsistency設定がeventualの場合、
          # masterからsecondaryにデータが行き渡る前に検索されると、
          # まだ存在しないと判断して生成しようとしエラーになるため、
          # 強制的に読み込みをstrongに変更する。
          @@session_class.with(consistency: :strong).find_or_create_by(id: id)
        end

        # def destroy(env)
        #   if sid = current_session_id(env)
        #     find_session(sid).destroy
        #   end
        # end

        def destroy(env)
          destroy_session(env, current_session_id(env), {})
        end

        def destroy_session(env, session_id, options)
          if sid = current_session_id(env)
            get_session_model(env, sid).destroy
            env[SESSION_RECORD_KEY] = nil
          end

          generate_sid unless options[:drop]
        end

        def get_session_model(env, sid)
          if env[ENV_SESSION_OPTIONS_KEY][:id].nil?
            env[SESSION_RECORD_KEY] = find_session(sid)
          else
            env[SESSION_RECORD_KEY] ||= find_session(sid)
          end
        end

        def pack(data)
          [Marshal.dump(data)].pack("m*")
        end

        def unpack(packed)
          return nil unless packed
          Marshal.load(packed.unpack("m*").first)
        end

    end
  end
end

MongoidStore = ActionDispatch::Session::MongoidStore
